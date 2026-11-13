import { createHash } from 'node:crypto';
import type { z } from 'zod';
import type { Region } from '@blazonguild/types';
import {
  AchievementsSummarySchema,
  CharacterEquipmentSchema,
  CharacterProfileSchema,
  CharacterSpecializationsSchema,
  CharacterStatisticsSchema,
  GuildRosterSchema,
  GuildSchema,
  MediaAssetsSchema,
  OAuthTokenSchema,
  ProfessionsSchema,
  PvpSummarySchema,
  SpecTalentTreeSchema,
  UserInfoSchema,
  UserWowProfileSchema,
} from './schemas';

export type NamespaceKind = 'profile' | 'dynamic' | 'static';

export interface BlizzardClientOptions {
  clientId: string;
  clientSecret: string;
  region: Region;
  locale?: string;
  fetchImpl?: typeof fetch;
  /** Simultaneous in-flight requests (Blizzard allows 100 req/s; we stay far below). */
  maxConcurrency?: number;
  timeoutMs?: number;
  maxRetries?: number;
}

export interface BlizzardResponse<T> {
  data: T;
  url: string;
  path: string;
  namespace: string;
  fetchedAt: Date;
  /** SHA-256 of the raw response body — used for change detection and provenance. */
  checksum: string;
  durationMs: number;
}

export class BlizzardApiError extends Error {
  constructor(
    message: string,
    readonly status: number | null,
    readonly path: string,
  ) {
    super(message);
    this.name = 'BlizzardApiError';
  }
}

class Semaphore {
  private active = 0;
  private queue: (() => void)[] = [];
  constructor(private readonly max: number) {}
  async run<T>(fn: () => Promise<T>): Promise<T> {
    if (this.active >= this.max) await new Promise<void>((resolve) => this.queue.push(resolve));
    this.active++;
    try {
      return await fn();
    } finally {
      this.active--;
      this.queue.shift()?.();
    }
  }
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Encode each path segment: Forever slugs contain non-ASCII letters (e.g. "c-a-ñ-a-d-a"). */
export function encodeSlug(slug: string) {
  return encodeURIComponent(slug.trim().toLowerCase());
}

export function sha256(text: string) {
  return createHash('sha256').update(text).digest('hex');
}

/**
 * Battle.net returns guild-crest and icon media under `/forever-{region}/…`, where many files answer 403.
 * The identical artwork is served under `/{region}/…` (verified 2026-11-12 for tabards and icons).
 * Character renders/avatars are character-specific and do work under `/forever-{region}/character/`.
 */
export function normalizeMediaUrl(url: string | null | undefined): string | null {
  if (!url) return null;
  return url.replace(/render\.worldofwarcraft\.com\/forever-([a-z]{2})\/(guild|icons)\//, 'render.worldofwarcraft.com/$1/$2/');
}

export class BlizzardClient {
  readonly region: Region;
  readonly locale: string;
  private readonly fetchImpl: typeof fetch;
  private readonly semaphore: Semaphore;
  private readonly timeoutMs: number;
  private readonly maxRetries: number;
  private token: { value: string; expiresAt: number } | null = null;
  private tokenPromise: Promise<string> | null = null;
  /** Blizzard pins static data to a build namespace; learned from any response `key.href`. */
  private staticNamespace: string | null = null;

  constructor(private readonly opts: BlizzardClientOptions) {
    this.region = opts.region;
    this.locale = opts.locale ?? 'es_ES';
    this.fetchImpl = opts.fetchImpl ?? fetch;
    this.semaphore = new Semaphore(opts.maxConcurrency ?? 8);
    this.timeoutMs = opts.timeoutMs ?? 10_000;
    this.maxRetries = opts.maxRetries ?? 3;
  }

  namespace(kind: NamespaceKind) {
    if (kind === 'static' && this.staticNamespace) return this.staticNamespace;
    return `${kind}-forever-${this.region}`;
  }

  get oauthHost() {
    // Global OAuth host for EU/US/KR/TW (CN is out of scope).
    return 'https://oauth.battle.net';
  }

  async getAccessToken(): Promise<string> {
    if (this.token && Date.now() < this.token.expiresAt - 60_000) return this.token.value;
    if (this.tokenPromise) return this.tokenPromise;
    this.tokenPromise = (async () => {
      const basic = Buffer.from(`${this.opts.clientId}:${this.opts.clientSecret}`).toString('base64');
      const res = await this.fetchImpl(`${this.oauthHost}/token`, {
        method: 'POST',
        headers: { Authorization: `Basic ${basic}`, 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'grant_type=client_credentials',
        signal: AbortSignal.timeout(this.timeoutMs),
      });
      if (!res.ok) throw new BlizzardApiError(`OAuth client_credentials failed (${res.status})`, res.status, '/token');
      const parsed = OAuthTokenSchema.parse(await res.json());
      this.token = { value: parsed.access_token, expiresAt: Date.now() + parsed.expires_in * 1000 };
      return parsed.access_token;
    })().finally(() => {
      this.tokenPromise = null;
    });
    return this.tokenPromise;
  }

  /**
   * GET a Battle.net resource. Returns `null` on 404 (resource does not exist),
   * throws BlizzardApiError on any other failure after retries.
   */
  async get<S extends z.ZodTypeAny>(
    path: string,
    kind: NamespaceKind,
    schema: S,
    opts: { userToken?: string; locale?: string | null } = {},
  ): Promise<BlizzardResponse<z.infer<S>> | null> {
    const namespace = this.namespace(kind);
    const params = new URLSearchParams({ namespace });
    const locale = opts.locale === undefined ? this.locale : opts.locale;
    if (locale) params.set('locale', locale);
    const url = `https://${this.region}.api.blizzard.com${path}?${params}`;

    return this.semaphore.run(async () => {
      let attempt = 0;
      let lastError: unknown;
      while (attempt <= this.maxRetries) {
        const started = Date.now();
        try {
          const token = opts.userToken ?? (await this.getAccessToken());
          const res = await this.fetchImpl(url, {
            headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
            signal: AbortSignal.timeout(this.timeoutMs),
          });
          if (res.status === 404) return null;
          if (res.status === 401 && !opts.userToken && attempt === 0) {
            this.token = null; // expired early — refresh once
            attempt++;
            continue;
          }
          if (res.status === 429 || res.status >= 500) {
            const retryAfter = Number(res.headers.get('retry-after'));
            lastError = new BlizzardApiError(`HTTP ${res.status} on ${path}`, res.status, path);
            await sleep(Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : 300 * 3 ** attempt);
            attempt++;
            continue;
          }
          const text = await res.text();
          if (!res.ok) throw new BlizzardApiError(`HTTP ${res.status} on ${path}: ${text.slice(0, 160)}`, res.status, path);
          const json = JSON.parse(text);
          this.learnStaticNamespace(text);
          const parsed = schema.safeParse(json);
          if (!parsed.success) {
            throw new BlizzardApiError(`Unexpected payload shape on ${path}: ${parsed.error.message.slice(0, 300)}`, res.status, path);
          }
          return {
            data: parsed.data,
            url,
            path,
            namespace,
            fetchedAt: new Date(),
            checksum: sha256(text),
            durationMs: Date.now() - started,
          };
        } catch (err) {
          if (err instanceof BlizzardApiError && err.status !== null && err.status < 500 && err.status !== 429) throw err;
          lastError = err;
          if (attempt >= this.maxRetries) break;
          await sleep(300 * 3 ** attempt);
          attempt++;
        }
      }
      if (lastError instanceof BlizzardApiError) throw lastError;
      throw new BlizzardApiError(`Network failure on ${path}: ${String((lastError as Error)?.message ?? lastError)}`, null, path);
    });
  }

  private learnStaticNamespace(body: string) {
    if (this.staticNamespace) return;
    const m = body.match(/namespace=(static-[0-9._]+-forever-[a-z]{2})/);
    if (m) this.staticNamespace = m[1];
  }

  // ---- Guilds -------------------------------------------------------------
  guild(slug: string) {
    return this.get(`/data/wow/guild/${encodeSlug(slug)}`, 'profile', GuildSchema);
  }
  guildRoster(slug: string) {
    return this.get(`/data/wow/guild/${encodeSlug(slug)}/roster`, 'profile', GuildRosterSchema);
  }

  // ---- Characters ---------------------------------------------------------
  character(slug: string) {
    return this.get(`/profile/wow/character/${encodeSlug(slug)}`, 'profile', CharacterProfileSchema);
  }
  characterEquipment(slug: string) {
    return this.get(`/profile/wow/character/${encodeSlug(slug)}/equipment`, 'profile', CharacterEquipmentSchema);
  }
  characterStatistics(slug: string) {
    return this.get(`/profile/wow/character/${encodeSlug(slug)}/statistics`, 'profile', CharacterStatisticsSchema);
  }
  characterSpecializations(slug: string) {
    return this.get(`/profile/wow/character/${encodeSlug(slug)}/specializations`, 'profile', CharacterSpecializationsSchema);
  }
  characterMedia(slug: string) {
    return this.get(`/profile/wow/character/${encodeSlug(slug)}/character-media`, 'profile', MediaAssetsSchema);
  }
  characterPvp(slug: string) {
    return this.get(`/profile/wow/character/${encodeSlug(slug)}/pvp-summary`, 'profile', PvpSummarySchema);
  }
  characterProfessions(slug: string) {
    return this.get(`/profile/wow/character/${encodeSlug(slug)}/professions`, 'profile', ProfessionsSchema);
  }
  characterAchievements(slug: string) {
    return this.get(`/profile/wow/character/${encodeSlug(slug)}/achievements`, 'profile', AchievementsSummarySchema);
  }

  // ---- Static game data ---------------------------------------------------
  itemMedia(itemId: number) {
    return this.get(`/data/wow/media/item/${itemId}`, 'static', MediaAssetsSchema);
  }
  spellMedia(spellId: number) {
    return this.get(`/data/wow/media/spell/${spellId}`, 'static', MediaAssetsSchema);
  }
  specMedia(specId: number) {
    return this.get(`/data/wow/media/playable-specialization/${specId}`, 'static', MediaAssetsSchema);
  }
  crestEmblem(id: number) {
    return this.get(`/data/wow/media/guild-crest/emblem/${id}`, 'static', MediaAssetsSchema, { locale: null });
  }
  crestBorder(id: number) {
    return this.get(`/data/wow/media/guild-crest/border/${id}`, 'static', MediaAssetsSchema, { locale: null });
  }
  specTalentTree(treeId: number, specId: number) {
    return this.get(`/data/wow/talent-tree/${treeId}/playable-specialization/${specId}`, 'static', SpecTalentTreeSchema);
  }

  // ---- Battle.net user (authorization_code flow) -----------------------------
  userWowProfile(userToken: string) {
    return this.get('/profile/user/wow', 'profile', UserWowProfileSchema, { userToken });
  }

  authorizeUrl(params: { redirectUri: string; state: string; scope?: string }) {
    const q = new URLSearchParams({
      client_id: this.opts.clientId,
      redirect_uri: params.redirectUri,
      response_type: 'code',
      scope: params.scope ?? 'openid wow.profile',
      state: params.state,
    });
    return `${this.oauthHost}/authorize?${q}`;
  }

  async exchangeCode(code: string, redirectUri: string) {
    const basic = Buffer.from(`${this.opts.clientId}:${this.opts.clientSecret}`).toString('base64');
    const res = await this.fetchImpl(`${this.oauthHost}/token`, {
      method: 'POST',
      headers: { Authorization: `Basic ${basic}`, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'authorization_code', code, redirect_uri: redirectUri }).toString(),
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!res.ok) throw new BlizzardApiError(`OAuth code exchange failed (${res.status})`, res.status, '/token');
    return OAuthTokenSchema.parse(await res.json());
  }

  async userInfo(userToken: string) {
    const res = await this.fetchImpl(`${this.oauthHost}/userinfo`, {
      headers: { Authorization: `Bearer ${userToken}` },
      signal: AbortSignal.timeout(this.timeoutMs),
    });
    if (!res.ok) throw new BlizzardApiError(`OAuth userinfo failed (${res.status})`, res.status, '/userinfo');
    return UserInfoSchema.parse(await res.json());
  }
}
