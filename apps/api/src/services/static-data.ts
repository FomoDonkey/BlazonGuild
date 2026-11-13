import { normalizeMediaUrl, type BlizzardClient, type SpecTalentTreePayload } from '@blazonguild/data-providers';
import { eq, inArray, items, staticCache, type Database } from '@blazonguild/database';
import type { Region } from '@blazonguild/types';
import type { Logger } from '../lib/logger';

const DAY = 24 * 3600 * 1000;

/**
 * Read-through cache for Battle.net static-namespace documents. Static data only changes
 * with game patches, so long TTLs keep us far away from the API quotas.
 */
export class StaticDataService {
  private inflight = new Map<string, Promise<unknown>>();

  constructor(
    private readonly db: Database,
    private readonly blizzard: (region: Region) => BlizzardClient,
    private readonly log: Logger,
  ) {}

  async cached<T>(key: string, ttlMs: number, loader: () => Promise<{ payload: T; namespace?: string } | null>): Promise<T | null> {
    const rows = await this.db.select().from(staticCache).where(eq(staticCache.key, key)).limit(1);
    const hit = rows[0];
    if (hit && Date.now() - hit.fetchedAt.getTime() < ttlMs) return hit.payload as T;

    const running = this.inflight.get(key);
    if (running) return running as Promise<T | null>;
    const p = (async () => {
      try {
        const loaded = await loader();
        const payload = loaded?.payload ?? null;
        await this.db
          .insert(staticCache)
          .values({ key, payload, namespace: loaded?.namespace ?? null, fetchedAt: new Date() })
          .onConflictDoUpdate({ target: staticCache.key, set: { payload, namespace: loaded?.namespace ?? null, fetchedAt: new Date() } });
        return payload;
      } catch (err) {
        this.log.warn('static-cache load failed', { key, err: String(err) });
        return (hit?.payload as T | undefined) ?? null; // serve stale on failure
      } finally {
        this.inflight.delete(key);
      }
    })();
    this.inflight.set(key, p);
    return p;
  }

  talentTree(region: Region, treeId: number, specId: number) {
    return this.cached<SpecTalentTreePayload>(`talent-tree:${region}:${treeId}:${specId}`, 7 * DAY, async () => {
      const res = await this.blizzard(region).specTalentTree(treeId, specId);
      return res ? { payload: res.data, namespace: res.namespace } : null;
    });
  }

  async spellIcon(region: Region, spellId: number) {
    return this.cached<string>(`spell-icon:${region}:${spellId}`, 30 * DAY, async () => {
      const res = await this.blizzard(region).spellMedia(spellId);
      const url = normalizeMediaUrl(res?.data.assets.find((a) => a.key === 'icon')?.value);
      return url ? { payload: url, namespace: res!.namespace } : null;
    });
  }

  async specIcon(region: Region, specId: number) {
    return this.cached<string>(`spec-icon:${region}:${specId}`, 30 * DAY, async () => {
      const res = await this.blizzard(region).specMedia(specId);
      const url = normalizeMediaUrl(res?.data.assets.find((a) => a.key === 'icon')?.value);
      return url ? { payload: url, namespace: res!.namespace } : null;
    });
  }

  async crestUrl(region: Region, kind: 'emblem' | 'border', id: number) {
    return this.cached<string>(`crest-${kind}:${region}:${id}`, 30 * DAY, async () => {
      const client = this.blizzard(region);
      const res = kind === 'emblem' ? await client.crestEmblem(id) : await client.crestBorder(id);
      const url = normalizeMediaUrl(res?.data.assets[0]?.value);
      return url ? { payload: url, namespace: res!.namespace } : null;
    });
  }

  /** Ensures icon URLs exist for the given items (fetched once per item, ever). */
  async ensureItemIcons(region: Region, itemIds: number[]) {
    if (!itemIds.length) return;
    const rows = await this.db.select({ id: items.id, iconUrl: items.iconUrl, fetched: items.mediaFetchedAt }).from(items).where(inArray(items.id, itemIds));
    const missing = rows.filter((r) => !r.iconUrl && !r.fetched).map((r) => r.id);
    await Promise.all(
      missing.map(async (id) => {
        try {
          const res = await this.blizzard(region).itemMedia(id);
          const url = normalizeMediaUrl(res?.data.assets.find((a) => a.key === 'icon')?.value);
          await this.db.update(items).set({ iconUrl: url, mediaFetchedAt: new Date() }).where(eq(items.id, id));
        } catch (err) {
          this.log.warn('item icon fetch failed', { id, err: String(err) });
        }
      }),
    );
  }
}
