import { createHash, createHmac, randomBytes, scrypt as scryptCb, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCb) as (pw: string, salt: Buffer, keylen: number, opts: object) => Promise<Buffer>;

/** OWASP-listed scrypt parameters (N=2^15, r=8, p=3 ≈ 32 MiB per hash). */
const PARAMS = { N: 2 ** 15, r: 8, p: 3, keylen: 64 };

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const key = await scrypt(password.normalize('NFKC'), salt, PARAMS.keylen, {
    N: PARAMS.N, r: PARAMS.r, p: PARAMS.p, maxmem: 128 * PARAMS.N * PARAMS.r * 2,
  });
  return `scrypt$${PARAMS.N}$${PARAMS.r}$${PARAMS.p}$${salt.toString('base64url')}$${key.toString('base64url')}`;
}

export async function verifyPassword(password: string, stored: string | null | undefined): Promise<boolean> {
  if (!stored) return false;
  const [algo, n, r, p, saltB64, keyB64] = stored.split('$');
  if (algo !== 'scrypt' || !saltB64 || !keyB64) return false;
  const N = Number(n), R = Number(r), P = Number(p);
  const expected = Buffer.from(keyB64, 'base64url');
  const key = await scrypt(password.normalize('NFKC'), Buffer.from(saltB64, 'base64url'), expected.length, {
    N, r: R, p: P, maxmem: 128 * N * R * 2,
  });
  return key.length === expected.length && timingSafeEqual(key, expected);
}

/** A dummy hash so that "unknown e-mail" and "wrong password" take the same time. */
let dummyHash: Promise<string> | null = null;
export function getDummyHash() {
  dummyHash ??= hashPassword('timing-equaliser-not-a-real-password');
  return dummyHash;
}

export function randomToken(bytes = 32) {
  return randomBytes(bytes).toString('base64url');
}

export function sha256(value: string) {
  return createHash('sha256').update(value).digest('hex');
}

export function hmac(secret: string, value: string) {
  return createHmac('sha256', secret).update(value).digest('base64url');
}

export function safeEqual(a: string, b: string) {
  const ab = Buffer.from(a), bb = Buffer.from(b);
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}
