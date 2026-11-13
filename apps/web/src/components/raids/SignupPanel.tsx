'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import type { CombatRole, RaidDetailDTO } from '@blazonguild/types';
import { clientApi, ClientApiError } from '@/lib/client-api';
import { classById, classVar, ROLE_LABEL } from '@/lib/game';
import { cn } from '@/lib/utils';

const STATUS = [
  { value: 'CONFIRMED', label: 'Voy' },
  { value: 'TENTATIVE', label: 'Quizá' },
  { value: 'DECLINED', label: 'No voy' },
] as const;

export function SignupPanel({ raid }: { raid: RaidDetailDTO }) {
  const router = useRouter();
  const mine = raid.signups.find((s) => s.isViewer);
  const chars = raid.viewer.characters;
  const [characterId, setCharacterId] = useState(mine?.character.id ?? chars[0]?.id ?? '');
  const char = chars.find((c) => c.id === characterId);
  const cls = classById(char?.classId);
  const [role, setRole] = useState<CombatRole>(mine?.role ?? (cls?.roles[0] === 'TANK' && cls.roles.length === 1 ? 'TANK' : cls?.roles.includes('DPS') ? 'DPS' : (cls?.roles[0] ?? 'DPS')));
  const [status, setStatus] = useState<'CONFIRMED' | 'TENTATIVE' | 'DECLINED'>(mine && mine.status !== 'BENCHED' ? mine.status : 'CONFIRMED');
  const [comment, setComment] = useState(mine?.comment ?? '');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const closed = raid.status === 'CANCELLED' || raid.status === 'COMPLETED';

  if (!raid.viewer.permissions.includes('raids.signup')) return null;
  if (!chars.length) {
    return (
      <div className="rounded-md border border-dashed border-line-strong/60 p-4 text-sm text-fg-2">
        No tienes personajes de esta hermandad vinculados a tu cuenta. <Link href="/settings" className="link">Vincúlalos con Battle.net</Link> para poder inscribirte.
      </div>
    );
  }

  const submit = async () => {
    setBusy(true);
    setMsg(null);
    try {
      await clientApi(`/v1/raids/${raid.id}/signup`, { method: 'PUT', body: { characterId, status, role, comment: comment.trim() || null } });
      setMsg({ ok: true, text: status === 'DECLINED' ? 'Has marcado que no asistes' : 'Inscripción guardada' });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: err instanceof ClientApiError ? err.message : 'No se pudo guardar la inscripción' });
    } finally {
      setBusy(false);
    }
  };

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        void submit();
      }}
      className="space-y-4 rounded-md border border-line bg-surface p-4"
      aria-labelledby="signup-title"
    >
      <h2 id="signup-title" className="t-display text-lg">
        {mine ? 'Tu inscripción' : 'Inscríbete'}
      </h2>
      <div className="space-y-1.5">
        <label htmlFor="signup-char" className="label">
          Personaje
        </label>
        <select id="signup-char" className="field" value={characterId} onChange={(e) => setCharacterId(e.target.value)} disabled={closed} style={{ color: classVar(char?.classId) }}>
          {chars.map((c) => (
            <option key={c.id} value={c.id}>
              {c.displayName} (nivel {c.level})
            </option>
          ))}
        </select>
      </div>
      <fieldset className="space-y-1.5">
        <legend className="label">Asistencia</legend>
        <div className="grid grid-cols-3 gap-1 rounded border border-line bg-sunken p-1">
          {STATUS.map((s) => (
            <label key={s.value} className={cn('flex min-h-[36px] cursor-pointer items-center justify-center rounded-sm text-sm', status === s.value ? 'bg-elevated text-fg' : 'text-fg-2')}>
              <input type="radio" name="status" value={s.value} checked={status === s.value} onChange={() => setStatus(s.value)} className="sr-only" disabled={closed} />
              {s.label}
            </label>
          ))}
        </div>
      </fieldset>
      {status !== 'DECLINED' && (
        <fieldset className="space-y-1.5">
          <legend className="label">Rol</legend>
          <div className="grid grid-cols-3 gap-1 rounded border border-line bg-sunken p-1">
            {(['TANK', 'HEALER', 'DPS'] as const).map((r) => {
              const allowed = cls?.roles.includes(r) ?? true;
              return (
                <label key={r} className={cn('flex min-h-[36px] items-center justify-center rounded-sm text-sm', role === r ? 'bg-elevated text-fg' : 'text-fg-2', allowed ? 'cursor-pointer' : 'cursor-not-allowed opacity-40')}>
                  <input type="radio" name="role" value={r} checked={role === r} onChange={() => setRole(r)} disabled={!allowed || closed} className="sr-only" />
                  {ROLE_LABEL[r]}
                </label>
              );
            })}
          </div>
          {cls && <p className="text-xs text-fg-3">Roles posibles para {cls.nameEs.toLowerCase()}: {cls.roles.map((r) => ROLE_LABEL[r].toLowerCase()).join(', ')}.</p>}
        </fieldset>
      )}
      <div className="space-y-1.5">
        <label htmlFor="signup-comment" className="label">
          Comentario (opcional)
        </label>
        <input id="signup-comment" className="field" maxLength={280} value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Llego 10 minutos tarde" disabled={closed} />
      </div>
      {msg && (
        <p role="status" className={cn('text-sm', msg.ok ? 'text-success' : 'text-danger')}>
          {msg.text}
        </p>
      )}
      <button type="submit" className="btn-primary w-full" disabled={busy || closed}>
        {closed ? 'La raid ya no admite inscripciones' : busy ? 'Guardando…' : mine ? 'Actualizar inscripción' : 'Inscribirme'}
      </button>
    </form>
  );
}
