import { z } from 'zod';

const bool = z
  .string()
  .optional()
  .transform((v) => v === 'true' || v === '1');

const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3001),
  /** postgres://… in production, pglite:<dir> in development, pglite:memory in tests. */
  DATABASE_URL: z.string().default('pglite:./.data/forever'),
  BLIZZARD_CLIENT_ID: z.string().min(1, 'BLIZZARD_CLIENT_ID is required'),
  BLIZZARD_CLIENT_SECRET: z.string().min(1, 'BLIZZARD_CLIENT_SECRET is required'),
  BLIZZARD_LOCALE: z.string().default('es_ES'),
  /** Public origin of the web platform (CSRF origin check, OAuth return URLs). */
  WEB_ORIGIN: z.string().url().default('http://localhost:3000'),
  /** Absolute redirect URI registered at develop.battle.net (enables Battle.net login). */
  BATTLENET_REDIRECT_URI: z.string().url().optional(),
  SESSION_SECRET: z.string().min(16).default('dev-only-session-secret-change-me'),
  TRUST_PROXY: bool,
  /** Disable the background scheduler (tests, one-off CLIs). */
  DISABLE_SCHEDULER: bool,
  MEDIA_CACHE_DIR: z.string().default('./.data/media-cache'),
});

export type Env = z.infer<typeof EnvSchema>;

export function loadEnv(source: Record<string, string | undefined> = process.env): Env {
  const parsed = EnvSchema.safeParse(source);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `  - ${i.path.join('.')}: ${i.message}`).join('\n');
    throw new Error(`Invalid environment configuration:\n${issues}`);
  }
  const env = parsed.data;
  if (env.NODE_ENV === 'production' && env.SESSION_SECRET.startsWith('dev-only')) {
    throw new Error('SESSION_SECRET must be set to a strong random value in production');
  }
  return env;
}
