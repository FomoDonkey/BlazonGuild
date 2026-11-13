'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import type { MeDTO } from '@blazonguild/types';
import { clientApi, ClientApiError } from '@/lib/client-api';

export function SettingsClient({ battlenetEnabled, characters }: { battlenetEnabled: boolean; characters: MeDTO['characters'] }) {
  const router = useRouter();
  const [mainId, setMainId] = useState(characters.find((c) => c.isMain)?.id ?? '');
  const [msg, setMsg] = useState<string | null>(null);
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <a
          href={battlenetEnabled ? '/api/v1/auth/battlenet/start?returnTo=/settings' : undefined}
          aria-disabled={!battlenetEnabled}
          className={`btn border border-[#148eff]/60 bg-[#0b5bd3] text-white ${battlenetEnabled ? 'hover:bg-[#0a6cff]' : 'pointer-events-none opacity-50'}`}
        >
          {characters.length ? 'Volver a sincronizar con Battle.net' : 'Vincular Battle.net'}
        </a>
        {!battlenetEnabled && <span className="text-xs text-fg-3">Pendiente de configurar en el servidor.</span>}
      </div>
      {characters.length > 1 && (
        <form
          className="flex flex-wrap items-end gap-2"
          onSubmit={async (e) => {
            e.preventDefault();
            try {
              await clientApi('/v1/me/main', { method: 'PUT', body: { characterId: mainId } });
              setMsg('Personaje principal actualizado');
              router.refresh();
            } catch (err) {
              setMsg(err instanceof ClientApiError ? err.message : 'No se pudo guardar');
            }
          }}
        >
          <div className="space-y-1.5">
            <label htmlFor="main" className="label">
              Personaje principal
            </label>
            <select id="main" className="field w-64" value={mainId} onChange={(e) => setMainId(e.target.value)}>
              {characters.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.displayName}
                </option>
              ))}
            </select>
          </div>
          <button type="submit" className="btn-secondary">
            Guardar
          </button>
          {msg && (
            <p role="status" className="w-full text-sm text-fg-2">
              {msg}
            </p>
          )}
        </form>
      )}
    </div>
  );
}
