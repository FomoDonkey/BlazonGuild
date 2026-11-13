'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Plus, X } from 'lucide-react';
import { RAID_INSTANCES } from '@blazonguild/types';
import { clientApi, ClientApiError } from '@/lib/client-api';
import { guildHref } from '@/lib/game';

function defaultStart() {
  const d = new Date();
  d.setDate(d.getDate() + ((4 - d.getDay() + 7) % 7 || 7)); // next Thursday
  d.setHours(20, 30, 0, 0);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function CreateRaidButton({ region, slug }: { region: string; slug: string }) {
  const ref = useRef<HTMLDialogElement>(null);
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [instanceKey, setInstanceKey] = useState('MC');
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const size = RAID_INSTANCES.find((i) => i.key === instanceKey)?.size ?? 40;

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  const submit = async (form: FormData) => {
    setBusy(true);
    setError(null);
    setFieldErrors({});
    const startLocal = String(form.get('startsAt'));
    const hours = Number(form.get('duration') || 0);
    const starts = new Date(startLocal);
    const body = {
      title: String(form.get('title')).trim(),
      instanceKey,
      startsAt: starts.toISOString(),
      endsAt: hours > 0 ? new Date(starts.getTime() + hours * 3_600_000).toISOString() : null,
      capacity: Number(form.get('capacity')),
      minLevel: form.get('minLevel') ? Number(form.get('minLevel')) : null,
      notes: String(form.get('notes') || '') || null,
    };
    try {
      const res = await clientApi<{ id: string }>(`/v1/guilds/${region}/${encodeURIComponent(slug)}/raids`, { method: 'POST', body });
      setOpen(false);
      router.push(guildHref(region, slug, `/raids/${res.id}`));
      router.refresh();
    } catch (err) {
      if (err instanceof ClientApiError) {
        setError(err.message);
        if (Array.isArray(err.details)) setFieldErrors(Object.fromEntries((err.details as { path: string; message: string }[]).map((d) => [d.path, d.message])));
      } else setError('No se pudo crear la raid');
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <button type="button" className="btn-primary" onClick={() => setOpen(true)}>
        <Plus className="h-4 w-4" aria-hidden /> Programar raid
      </button>
      <dialog ref={ref} onClose={() => setOpen(false)} className="w-[min(560px,calc(100vw-24px))] max-w-none rounded-lg border border-line-strong bg-surface p-0 text-fg shadow-tooltip backdrop:bg-black/60" aria-labelledby="create-raid-title">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void submit(new FormData(e.currentTarget));
          }}
          className="space-y-4 p-5"
        >
          <div className="flex items-center justify-between">
            <h2 id="create-raid-title" className="t-display text-xl">
              Programar raid
            </h2>
            <button type="button" onClick={() => setOpen(false)} className="btn-ghost h-10 w-10 px-0" aria-label="Cerrar">
              <X className="h-5 w-5" aria-hidden />
            </button>
          </div>
          <div className="space-y-1.5">
            <label htmlFor="raid-title" className="label">
              Título
            </label>
            <input id="raid-title" name="title" required minLength={3} maxLength={80} placeholder="Núcleo de Magma, noche de progreso" className="field" aria-invalid={!!fieldErrors.title} />
            {fieldErrors.title && <p className="text-xs text-danger">{fieldErrors.title}</p>}
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <label htmlFor="raid-instance" className="label">
                Instancia
              </label>
              <select id="raid-instance" value={instanceKey} onChange={(e) => setInstanceKey(e.target.value)} className="field">
                {RAID_INSTANCES.map((i) => (
                  <option key={i.key} value={i.key}>
                    {i.nameEs}
                  </option>
                ))}
              </select>
            </div>
            <div className="space-y-1.5">
              <label htmlFor="raid-start" className="label">
                Inicio
              </label>
              <input id="raid-start" name="startsAt" type="datetime-local" required defaultValue={defaultStart()} className="field" />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="raid-duration" className="label">
                Duración (horas, opcional)
              </label>
              <input id="raid-duration" name="duration" type="number" min={0} max={12} step={0.5} defaultValue={3} className="field" />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="raid-capacity" className="label">
                Plazas
              </label>
              <input key={size} id="raid-capacity" name="capacity" type="number" min={5} max={40} defaultValue={size} className="field" />
            </div>
            <div className="space-y-1.5">
              <label htmlFor="raid-minlevel" className="label">
                Nivel mínimo (opcional)
              </label>
              <input id="raid-minlevel" name="minLevel" type="number" min={1} max={60} className="field" />
            </div>
          </div>
          <div className="space-y-1.5">
            <label htmlFor="raid-notes" className="label">
              Notas para la banda
            </label>
            <textarea id="raid-notes" name="notes" rows={3} maxLength={2000} className="field min-h-[88px] py-2" placeholder="Consumibles, resistencias, estrategia…" />
          </div>
          {error && (
            <p role="alert" className="rounded border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-fg">
              {error}
            </p>
          )}
          <div className="flex justify-end gap-2 pt-1">
            <button type="button" onClick={() => setOpen(false)} className="btn-ghost">
              Cancelar
            </button>
            <button type="submit" className="btn-primary" disabled={busy}>
              {busy ? 'Creando…' : 'Crear y avisar a la hermandad'}
            </button>
          </div>
        </form>
      </dialog>
    </>
  );
}
