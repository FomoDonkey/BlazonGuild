import { cache } from 'react';
import { cookies, headers } from 'next/headers';
import type { CharacterArmoryDTO, GuildOverviewDTO, MeDTO } from '@blazonguild/types';

const API = process.env.API_INTERNAL_URL ?? 'http://127.0.0.1:3001';

export class ApiFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

/** Server-side call to BlazonGuild Core, forwarding the visitor's session cookie and IP. */
export async function api<T>(path: string): Promise<T> {
  const [jar, h] = await Promise.all([cookies(), headers()]);
  const forwarded = h.get('x-forwarded-for') ?? h.get('x-real-ip') ?? '';
  let res: Response;
  try {
    res = await fetch(`${API}${path}`, {
      headers: { cookie: jar.toString(), accept: 'application/json', ...(forwarded ? { 'x-forwarded-for': forwarded } : {}) },
      cache: 'no-store',
    });
  } catch {
    throw new ApiFailure(503, 'API_UNREACHABLE', 'El servidor de BlazonGuild no responde. Comprueba que la API está en marcha.');
  }
  if (!res.ok) {
    let code = `HTTP_${res.status}`;
    let message = res.statusText;
    try {
      const body = await res.json();
      code = body?.error?.code ?? code;
      message = body?.error?.message ?? message;
    } catch {
      /* non-JSON error body */
    }
    throw new ApiFailure(res.status, code, message);
  }
  return res.json() as Promise<T>;
}

export async function apiOrNull<T>(path: string): Promise<T | null> {
  try {
    return await api<T>(path);
  } catch (err) {
    if (err instanceof ApiFailure && (err.status === 404 || err.status === 401 || err.status === 403)) return null;
    throw err;
  }
}

export const getMe = cache(async (): Promise<MeDTO | null> => {
  try {
    return await api<MeDTO>('/v1/auth/me');
  } catch (err) {
    if (err instanceof ApiFailure && (err.status === 401 || err.status === 503)) return null;
    throw err;
  }
});

const seg = (s: string) => encodeURIComponent(decodeURIComponent(s));
export const guildPath = (region: string, slug: string) => `/v1/guilds/${seg(region)}/${seg(slug)}`;

export const getGuildOverview = cache((region: string, slug: string) => api<GuildOverviewDTO>(guildPath(region, slug)));
export const getArmory = cache((region: string, slug: string) => api<CharacterArmoryDTO>(`/v1/characters/${seg(region)}/${seg(slug)}`));
