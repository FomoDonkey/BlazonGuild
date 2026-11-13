import { and, characterSnapshots, characters, desc, eq, inArray, isNull, notInArray, users } from '@blazonguild/database';
import type { Region } from '@blazonguild/types';
import type { AppDeps } from '../context';
import { audit } from '../lib/audit';
import { hmac, randomToken, safeEqual } from '../lib/crypto';

/**
 * Battle.net OAuth (authorization_code) — proves ownership of WoW: Forever characters.
 * The state is an HMAC-signed, short-lived value stored in an httpOnly cookie.
 */
export function signState(secret: string, payload: { returnTo: string; region: Region; nonce?: string; exp?: number }) {
  const body = Buffer.from(
    JSON.stringify({ ...payload, nonce: payload.nonce ?? randomToken(12), exp: payload.exp ?? Date.now() + 10 * 60_000 }),
  ).toString('base64url');
  return `${body}.${hmac(secret, body)}`;
}

export function verifyState(secret: string, value: string | undefined | null): { returnTo: string; region: Region; nonce: string } | null {
  if (!value) return null;
  const [body, sig] = value.split('.');
  if (!body || !sig || !safeEqual(sig, hmac(secret, body))) return null;
  try {
    const parsed = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (typeof parsed.exp !== 'number' || parsed.exp < Date.now()) return null;
    return parsed;
  } catch {
    return null;
  }
}

/** Only same-site relative paths are accepted as post-login destinations (no open redirects). */
export function safeReturnTo(value: string | undefined | null) {
  if (!value || !value.startsWith('/') || value.startsWith('//') || value.includes('\\')) return '/';
  return value;
}

export async function completeBattlenetLogin(deps: AppDeps, region: Region, code: string, currentUserId: string | null, meta: { ip: string; ua?: string }) {
  const client = deps.blizzard(region);
  const redirectUri = deps.env.BATTLENET_REDIRECT_URI!;
  const token = await client.exchangeCode(code, redirectUri);
  const info = await client.userInfo(token.access_token);
  const battleTag = info.battletag ?? null;

  // Resolve the account: already linked → that user; logged in → link; otherwise create.
  let user = (await deps.db.select().from(users).where(eq(users.battlenetId, info.id)).limit(1))[0];
  if (!user && currentUserId) {
    [user] = await deps.db.update(users).set({ battlenetId: info.id, battleTag }).where(eq(users.id, currentUserId)).returning();
    await audit(deps.db, { actorUserId: user.id, action: 'BATTLENET_LINK', entity: 'user', entityId: user.id, changes: { battleTag }, ip: meta.ip, userAgent: meta.ua });
  }
  if (!user) {
    [user] = await deps.db
      .insert(users)
      .values({ email: `bnet-${info.id}@battlenet.invalid`, displayName: battleTag?.split('#')[0] ?? `Jugador ${info.id}`, battlenetId: info.id, battleTag })
      .returning();
    await audit(deps.db, { actorUserId: user.id, action: 'USER_CREATE_BATTLENET', entity: 'user', entityId: user.id, changes: { battleTag }, ip: meta.ip, userAgent: meta.ua });
  } else if (battleTag && user.battleTag !== battleTag) {
    await deps.db.update(users).set({ battleTag }).where(eq(users.id, user.id));
  }

  // Characters on the account → verified ownership.
  const profile = await client.userWowProfile(token.access_token);
  const owned = (profile?.data.wow_accounts ?? []).flatMap((a) => a.characters);
  const slugs: string[] = [];
  for (const ch of owned) {
    const slug = (ch.slug ?? [ch.name, ch.surname].filter(Boolean).join('-')).toLowerCase();
    if (!slug) continue;
    slugs.push(slug);
    try {
      await deps.sync.syncCharacter(region, slug, { trigger: 'MANUAL', userId: user.id });
    } catch (err) {
      deps.log.warn('owned character sync failed', { slug, err: String(err) });
    }
  }
  if (slugs.length) {
    await deps.db
      .update(characters)
      .set({ ownerUserId: user.id, ownershipVerified: true })
      .where(and(eq(characters.region, region), inArray(characters.slug, slugs)));
  }
  // Characters previously verified for this user but no longer on the Battle.net account lose verification.
  await deps.db
    .update(characters)
    .set({ ownerUserId: null, ownershipVerified: false, isMain: false })
    .where(and(eq(characters.ownerUserId, user.id), eq(characters.region, region), eq(characters.ownershipVerified, true), slugs.length ? notInArray(characters.slug, slugs) : undefined));

  // Import the guilds of owned characters that BlazonGuild does not track yet, so ranks are known.
  if (slugs.length) {
    const unlinked = await deps.db
      .select({ id: characters.id })
      .from(characters)
      .where(and(eq(characters.region, region), inArray(characters.slug, slugs), isNull(characters.guildId)));
    for (const { id } of unlinked) {
      const snap = (await deps.db.select({ profile: characterSnapshots.profile }).from(characterSnapshots).where(eq(characterSnapshots.characterId, id)).orderBy(desc(characterSnapshots.takenAt)).limit(1))[0];
      const guildSlug = (snap?.profile as { guild?: { slug?: string } } | undefined)?.guild?.slug;
      if (!guildSlug) continue;
      try {
        await deps.sync.syncGuild(region, guildSlug, { trigger: "MANUAL", userId: user.id, details: "none", awaitDetails: true });
      } catch (err) {
        deps.log.warn("guild import during login failed", { guildSlug, err: String(err) });
      }
    }
  }

  const guildIds = slugs.length
    ? (await deps.db.select({ g: characters.guildId }).from(characters).where(and(eq(characters.region, region), inArray(characters.slug, slugs)))).map((r) => r.g).filter((g): g is string => !!g)
    : [];
  for (const g of new Set(guildIds)) await deps.sync.reconcileMemberships(g);
  await deps.db.update(users).set({ lastLoginAt: deps.now() }).where(eq(users.id, user.id));
  return { user, characters: slugs.length };
}
