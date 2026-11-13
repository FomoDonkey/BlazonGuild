'use client';

import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { useState } from 'react';
import { clientApi, ClientApiError } from '@/lib/client-api';

const ERRORS: Record<string, string> = {
  state: 'La sesión de Battle.net caducó o no es válida. Vuelve a intentarlo.',
  denied: 'Has cancelado el acceso en Battle.net.',
  battlenet: 'Battle.net no ha podido completar el inicio de sesión. Inténtalo de nuevo en unos minutos.',
};

export function AuthForm({ mode, battlenetEnabled }: { mode: 'login' | 'register'; battlenetEnabled: boolean }) {
  const router = useRouter();
  const params = useSearchParams();
  const returnTo = params.get('returnTo')?.startsWith('/') ? params.get('returnTo')! : '/';
  const [error, setError] = useState<string | null>(ERRORS[params.get('error') ?? ''] ?? null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);

  const submit = async (form: FormData) => {
    setBusy(true);
    setError(null);
    setFieldErrors({});
    try {
      const body: Record<string, string> = { email: String(form.get('email')), password: String(form.get('password')) };
      if (mode === 'register') body.displayName = String(form.get('displayName'));
      await clientApi(`/v1/auth/${mode}`, { method: 'POST', body });
      router.push(returnTo);
      router.refresh();
    } catch (err) {
      if (err instanceof ClientApiError) {
        setError(err.message);
        if (Array.isArray(err.details)) setFieldErrors(Object.fromEntries((err.details as { path: string; message: string }[]).map((d) => [d.path, d.message])));
      } else setError('No se pudo conectar con BlazonGuild');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-6">
      <a
        href={battlenetEnabled ? `/api/v1/auth/battlenet/start?returnTo=${encodeURIComponent(returnTo)}` : undefined}
        aria-disabled={!battlenetEnabled}
        className={`btn w-full border border-[#148eff]/60 bg-[#0b5bd3] text-white ${battlenetEnabled ? 'hover:bg-[#0a6cff]' : 'pointer-events-none opacity-50'}`}
      >
        Continuar con Battle.net
      </a>
      <p className="-mt-3 text-xs text-fg-3">
        {battlenetEnabled
          ? 'Recomendado: verifica qué personajes son tuyos y te da tu rol según el rango que tengas en la hermandad.'
          : 'El inicio de sesión con Battle.net aún no está activado en este servidor (falta registrar la URL de retorno en develop.battle.net).'}
      </p>
      <div className="flex items-center gap-3 text-xs text-fg-3">
        <span className="h-px flex-1 bg-line" /> o con email <span className="h-px flex-1 bg-line" />
      </div>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          void submit(new FormData(e.currentTarget));
        }}
        className="space-y-4"
        noValidate
      >
        {mode === 'register' && (
          <div className="space-y-1.5">
            <label htmlFor="displayName" className="label">
              Nombre visible
            </label>
            <input id="displayName" name="displayName" required minLength={2} maxLength={40} autoComplete="nickname" className="field" aria-invalid={!!fieldErrors.displayName} aria-describedby={fieldErrors.displayName ? 'err-displayName' : undefined} />
            {fieldErrors.displayName && <p id="err-displayName" className="text-xs text-danger">{fieldErrors.displayName}</p>}
          </div>
        )}
        <div className="space-y-1.5">
          <label htmlFor="email" className="label">
            Email
          </label>
          <input id="email" name="email" type="email" required autoComplete="email" className="field" aria-invalid={!!fieldErrors.email} aria-describedby={fieldErrors.email ? 'err-email' : undefined} />
          {fieldErrors.email && <p id="err-email" className="text-xs text-danger">{fieldErrors.email}</p>}
        </div>
        <div className="space-y-1.5">
          <label htmlFor="password" className="label">
            Contraseña
          </label>
          <input id="password" name="password" type="password" required minLength={mode === 'register' ? 10 : 1} autoComplete={mode === 'register' ? 'new-password' : 'current-password'} className="field" aria-invalid={!!fieldErrors.password} aria-describedby={mode === 'register' ? 'pw-help' : fieldErrors.password ? 'err-password' : undefined} />
          {mode === 'register' && (
            <p id="pw-help" className="text-xs text-fg-3">
              Mínimo 10 caracteres.
            </p>
          )}
          {fieldErrors.password && <p id="err-password" className="text-xs text-danger">{fieldErrors.password}</p>}
        </div>
        {error && (
          <p role="alert" className="rounded border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-fg">
            {error}
          </p>
        )}
        <button type="submit" className="btn-primary w-full" disabled={busy}>
          {busy ? 'Un momento…' : mode === 'login' ? 'Entrar' : 'Crear cuenta'}
        </button>
      </form>
      <p className="text-center text-sm text-fg-2">
        {mode === 'login' ? (
          <>
            ¿Aún no tienes cuenta? <Link href={`/register?returnTo=${encodeURIComponent(returnTo)}`} className="link">Crear cuenta</Link>
          </>
        ) : (
          <>
            ¿Ya tienes cuenta? <Link href={`/login?returnTo=${encodeURIComponent(returnTo)}`} className="link">Entrar</Link>
          </>
        )}
      </p>
    </div>
  );
}
