import type { ContentfulStatusCode } from 'hono/utils/http-status';

export class ApiError extends Error {
  constructor(
    readonly status: ContentfulStatusCode,
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export const badRequest = (message: string, details?: unknown) => new ApiError(400, 'BAD_REQUEST', message, details);
export const unauthorized = (message = 'Necesitas iniciar sesión') => new ApiError(401, 'UNAUTHORIZED', message);
export const forbidden = (message = 'No tienes permiso para esta acción') => new ApiError(403, 'FORBIDDEN', message);
export const notFound = (message = 'Recurso no encontrado') => new ApiError(404, 'NOT_FOUND', message);
export const conflict = (message: string, details?: unknown) => new ApiError(409, 'CONFLICT', message, details);
export const tooMany = (message = 'Demasiadas solicitudes, inténtalo en un momento') => new ApiError(429, 'RATE_LIMITED', message);
export const upstream = (message: string) => new ApiError(502, 'UPSTREAM_ERROR', message);
