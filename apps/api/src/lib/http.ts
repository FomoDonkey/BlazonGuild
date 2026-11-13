import { OpenAPIHono, type z } from '@hono/zod-openapi';
import type { AppEnv } from '../context';
import { ApiError } from './errors';

/** Router factory with a uniform validation-error format. */
export function router() {
  return new OpenAPIHono<AppEnv>({
    defaultHook: (result) => {
      if (!result.success) {
        throw new ApiError(400, 'VALIDATION_FAILED', 'Datos de entrada no válidos', result.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })));
      }
    },
  });
}

export const json = <T extends z.ZodType>(description: string, schema: T) => ({
  description,
  content: { 'application/json': { schema } },
});

export function clampPage(page?: number, pageSize?: number, max = 100) {
  const p = Math.max(1, Math.floor(page ?? 1));
  const s = Math.min(max, Math.max(1, Math.floor(pageSize ?? 25)));
  return { page: p, pageSize: s, offset: (p - 1) * s };
}
