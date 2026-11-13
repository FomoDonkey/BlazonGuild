'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';
import { RefreshCw } from 'lucide-react';
import { clientApi, ClientApiError } from '@/lib/client-api';

export function SyncCharacterButton({ region, slug }: { region: string; slug: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [, start] = useTransition();
  return (
    <div>
      <button
        type="button"
        className="btn-secondary h-9 min-h-0 px-3 text-xs"
        disabled={busy}
        onClick={async () => {
          setBusy(true);
          setError(null);
          try {
            await clientApi(`/v1/characters/${region}/${encodeURIComponent(slug)}/sync`, { method: 'POST', body: {} });
            start(() => router.refresh());
          } catch (err) {
            setError(err instanceof ClientApiError ? err.message : 'No se pudo actualizar');
          } finally {
            setBusy(false);
          }
        }}
      >
        <RefreshCw className={`h-3.5 w-3.5 ${busy ? 'animate-spin' : ''}`} aria-hidden />
        {busy ? 'Actualizando…' : 'Actualizar desde Battle.net'}
      </button>
      {error && (
        <p role="alert" className="mt-1 text-xs text-danger">
          {error}
        </p>
      )}
    </div>
  );
}
