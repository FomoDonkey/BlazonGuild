import { describe, expect, it } from 'vitest';
import { BlizzardClient } from '@blazonguild/data-providers';
import { safeReturnTo, signState, verifyState } from '../src/auth/battlenet';

const SECRET = 'test-secret-with-enough-length';

describe('Battle.net OAuth helpers', () => {
  it('round-trips a signed state', () => {
    const s = signState(SECRET, { returnTo: '/g/eu/forever', region: 'eu' });
    expect(verifyState(SECRET, s)).toMatchObject({ returnTo: '/g/eu/forever', region: 'eu' });
  });

  it('rejects tampered, foreign-key and expired states', () => {
    const s = signState(SECRET, { returnTo: '/', region: 'eu' });
    const [body, sig] = s.split('.');
    const forged = Buffer.from(JSON.stringify({ returnTo: '//evil.example', region: 'eu', nonce: 'x', exp: Date.now() + 60_000 })).toString('base64url');
    expect(verifyState(SECRET, `${forged}.${sig}`)).toBeNull();
    expect(verifyState('another-secret-value-123456', s)).toBeNull();
    expect(verifyState(SECRET, signState(SECRET, { returnTo: '/', region: 'eu', exp: Date.now() - 1 }))).toBeNull();
    expect(verifyState(SECRET, `${body}`)).toBeNull();
    expect(verifyState(SECRET, null)).toBeNull();
  });

  it('only accepts same-site relative return paths (no open redirects)', () => {
    expect(safeReturnTo('/settings')).toBe('/settings');
    for (const bad of ['https://evil.example', '//evil.example', '/\\evil.example', 'javascript:alert(1)', '', null, undefined]) {
      expect(safeReturnTo(bad as string)).toBe('/');
    }
  });

  it('builds the authorize URL with the wow.profile scope and the exact redirect URI', () => {
    const c = new BlizzardClient({ clientId: 'cid', clientSecret: 'x', region: 'eu' });
    const url = new URL(c.authorizeUrl({ redirectUri: 'http://localhost:3000/api/v1/auth/battlenet/callback', state: 'abc' }));
    expect(url.origin + url.pathname).toBe('https://oauth.battle.net/authorize');
    expect(url.searchParams.get('scope')).toBe('openid wow.profile');
    expect(url.searchParams.get('redirect_uri')).toBe('http://localhost:3000/api/v1/auth/battlenet/callback');
    expect(url.searchParams.get('state')).toBe('abc');
  });
});
