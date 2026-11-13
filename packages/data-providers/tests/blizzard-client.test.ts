import { describe, expect, it, vi } from 'vitest';
import { BlizzardApiError, BlizzardClient, encodeSlug, normalizeMediaUrl } from '../src';

function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...headers } });
}

function makeClient(handler: (url: string, init?: RequestInit) => Response | Promise<Response>) {
  const fetchImpl = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith('/token')) return jsonResponse({ access_token: 'tok', token_type: 'bearer', expires_in: 86399 });
    return handler(url, init);
  });
  const client = new BlizzardClient({ clientId: 'id', clientSecret: 'secret', region: 'eu', fetchImpl: fetchImpl as typeof fetch, maxRetries: 2 });
  return { client, fetchImpl };
}

describe('BlizzardClient', () => {
  it('encodes non-ASCII slugs per segment', () => {
    expect(encodeSlug('E-S-P-A-Ñ-A')).toBe('c-a-%C3%B1-a-d-a');
  });

  it('rewrites broken forever guild-crest media paths', () => {
    expect(normalizeMediaUrl('https://render.worldofwarcraft.com/forever-eu/guild/tabards/emblem_98.png')).toBe(
      'https://render.worldofwarcraft.com/eu/guild/tabards/emblem_98.png',
    );
    expect(normalizeMediaUrl('https://render.worldofwarcraft.com/forever-eu/icons/56/133762.jpg')).toBe(
      'https://render.worldofwarcraft.com/eu/icons/56/133762.jpg',
    );
    expect(normalizeMediaUrl('https://render.worldofwarcraft.com/forever-eu/character/71/1-main-raw.png')).toBe(
      'https://render.worldofwarcraft.com/forever-eu/character/71/1-main-raw.png',
    );
  });

  it('uses forever namespaces, validates and checksums the payload', async () => {
    const { client } = makeClient((url) => {
      expect(url).toContain('/data/wow/guild/forever?namespace=profile-forever-eu&locale=es_ES');
      return jsonResponse({ id: 94195, name: 'Forever', slug: 'forever', faction: { type: 'HORDE' }, member_count: 55 });
    });
    const res = await client.guild('forever');
    expect(res?.data.member_count).toBe(55);
    expect(res?.checksum).toMatch(/^[a-f0-9]{64}$/);
    expect(res?.namespace).toBe('profile-forever-eu');
  });

  it('returns null on 404', async () => {
    const { client } = makeClient(() => jsonResponse({ code: 404 }, 404));
    expect(await client.character('nobody-here')).toBeNull();
  });

  it('retries 429 then succeeds', async () => {
    let calls = 0;
    const { client } = makeClient(() => {
      calls++;
      return calls === 1 ? jsonResponse({}, 429, { 'retry-after': '0' }) : jsonResponse({ honorable_kills: 68, pvp_rank: 0 });
    });
    const res = await client.characterPvp('goa-smashie');
    expect(res?.data.honorable_kills).toBe(68);
    expect(calls).toBe(2);
  });

  it('throws a typed error on unexpected payloads', async () => {
    const { client } = makeClient(() => jsonResponse({ nope: true }));
    await expect(client.guild('forever')).rejects.toBeInstanceOf(BlizzardApiError);
  });

  it('learns the pinned static namespace from responses', async () => {
    const { client } = makeClient(() =>
      jsonResponse({
        id: 1, name: 'X', slug: 'x', faction: { type: 'HORDE' },
        _links: { self: { href: 'https://eu.api.blizzard.com/x?namespace=static-1.60.1_70399-forever-eu' } },
      }),
    );
    await client.guild('x');
    expect(client.namespace('static')).toBe('static-1.60.1_70399-forever-eu');
  });
});

describe('schema resilience (real-world quirks)', () => {
  it('drops only the malformed equipment item, keeps the rest', async () => {
    const { CharacterEquipmentSchema } = await import('../src/schemas');
    const parsed = CharacterEquipmentSchema.parse({
      equipped_items: [
        { item: { id: 1 }, slot: { type: 'HEAD' }, name: 'Casco', stats: [{ display: { display_string: '+1 a todas las resistencias' } }] },
        { slot: { type: 'NECK' } },
        { item: { id: 3 }, slot: { type: 'BACK' }, spells: [{ spell: { id: 9, name: null }, description: 'x' }] },
      ],
    });
    expect(parsed.equipped_items.map((i) => i.item.id)).toEqual([1, 3]);
  });
});
