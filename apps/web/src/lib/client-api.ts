'use client';

export class ClientApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
  }
}

/** Browser-side call through the same-origin `/api` rewrite (cookies stay first-party). */
export async function clientApi<T>(path: string, init: { method?: string; body?: unknown; signal?: AbortSignal } = {}): Promise<T> {
  const res = await fetch(`/api${path}`, {
    method: init.method ?? 'GET',
    headers: init.body !== undefined ? { 'content-type': 'application/json' } : undefined,
    body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
    credentials: 'same-origin',
    signal: init.signal,
  });
  if (res.status === 204) return undefined as T;
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    throw new ClientApiError(res.status, data?.error?.code ?? `HTTP_${res.status}`, data?.error?.message ?? 'Error inesperado', data?.error?.details);
  }
  return data as T;
}
