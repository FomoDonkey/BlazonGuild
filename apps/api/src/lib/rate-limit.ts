import type { MiddlewareHandler } from 'hono';
import type { AppEnv } from '../context';
import { tooMany } from './errors';

/**
 * Fixed-window in-memory rate limiter. Adequate for a single API instance; swap for a
 * shared store (Redis/Postgres) before running several replicas.
 */
export class RateLimiter {
  private hits = new Map<string, { count: number; resetAt: number }>();
  constructor(private readonly limit: number, private readonly windowMs: number) {}

  take(key: string, now = Date.now()) {
    const entry = this.hits.get(key);
    if (!entry || entry.resetAt <= now) {
      this.hits.set(key, { count: 1, resetAt: now + this.windowMs });
      if (this.hits.size > 50_000) this.sweep(now);
      return { ok: true, remaining: this.limit - 1, resetAt: now + this.windowMs };
    }
    entry.count++;
    return { ok: entry.count <= this.limit, remaining: Math.max(0, this.limit - entry.count), resetAt: entry.resetAt };
  }

  private sweep(now: number) {
    for (const [k, v] of this.hits) if (v.resetAt <= now) this.hits.delete(k);
  }
}

export function rateLimit(limiter: RateLimiter, keyOf: (c: Parameters<MiddlewareHandler<AppEnv>>[0]) => string): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    const r = limiter.take(keyOf(c));
    c.header('RateLimit-Remaining', String(r.remaining));
    c.header('RateLimit-Reset', String(Math.ceil((r.resetAt - Date.now()) / 1000)));
    if (!r.ok) {
      c.header('Retry-After', String(Math.ceil((r.resetAt - Date.now()) / 1000)));
      throw tooMany();
    }
    await next();
  };
}
