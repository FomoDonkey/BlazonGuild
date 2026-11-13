'use client';

import { useEffect } from 'react';

export default function GlobalError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    console.error(error);
  }, [error]);
  return (
    <div className="mx-auto max-w-xl px-4 py-16">
      <div role="alert" className="rounded-md border border-danger/40 bg-danger/5 p-5">
        <h1 className="t-display text-2xl">Algo ha fallado al cargar esta página</h1>
        <p className="mt-2 text-sm text-fg-2">{error.message || 'Error inesperado.'} Si el problema continúa, comprueba que la API de BlazonGuild está en marcha.</p>
        {error.digest && <p className="mt-1 text-xs text-fg-3">Referencia: {error.digest}</p>}
        <button type="button" onClick={reset} className="btn-primary mt-4">
          Reintentar
        </button>
      </div>
    </div>
  );
}
