'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Cross, Plus, Shield, Swords, X } from 'lucide-react';
import { DUNGEONS, type CombatRole } from '@blazonguild/types';
import { zoneArt } from '@/components/art/raid-art';
import { ClassIcon } from '@/components/game/bits';
import { clientApi, ClientApiError } from '@/lib/client-api';
import { fmtDateTime } from '@/lib/format';
import { classById, classVar, ROLE_LABEL } from '@/lib/game';
import { cn } from '@/lib/utils';

export interface GroupDTO {
  id: string;
  dungeon: { key: string; name: string; min: number; max: number; size: number };
  note: string | null;
  startsAt: string | null;
  isLeader: boolean;
  needs: Record<CombatRole, number>;
  members: { userId: string; role: CombatRole; isViewer: boolean; character: { id: string; slug: string; region: string; displayName: string; classId: number; level: number } }[];
}

interface MyChar {
  id: string;
  displayName: string;
  classId: number;
  level: number;
}

const ROLE_ICON = { TANK: Shield, HEALER: Cross, DPS: Swords } as const;

export function GroupFinder({ region, slug, groups, myChars, canCreate, preset }: { region: string; slug: string; groups: GroupDTO[]; myChars: MyChar[]; canCreate: boolean; preset?: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(!!preset);
  const [dungeon, setDungeon] = useState(preset ?? 'SM');
  const [charId, setCharId] = useState(myChars[0]?.id ?? '');
  const char = myChars.find((c) => c.id === charId);
  const roles = classById(char?.classId)?.roles ?? ['DPS'];
  const [role, setRole] = useState<CombatRole>(roles.includes('DPS') ? 'DPS' : roles[0]);
  const [note, setNote] = useState('');
  const [when, setWhen] = useState('');
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const base = `/v1/guilds/${region}/${encodeURIComponent(slug)}`;

  const act = async (fn: () => Promise<unknown>, ok: string) => {
    setBusy(true);
    setMsg(null);
    try {
      await fn();
      setMsg({ ok: true, text: ok });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: err instanceof ClientApiError ? err.message : 'No se pudo completar' });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-5">
      {canCreate && (
        <div>
          {!open ? (
            <button type="button" className="btn-primary" onClick={() => setOpen(true)} disabled={!myChars.length}>
              <Plus className="h-4 w-4" aria-hidden /> Formar un grupo
            </button>
          ) : (
            <form
              className="plate relative grid gap-4 rounded-[4px] p-5 sm:grid-cols-2 lg:grid-cols-4"
              onSubmit={(e) => {
                e.preventDefault();
                void act(
                  () => clientApi(`${base}/groups`, { method: 'POST', body: { dungeonKey: dungeon, characterId: charId, role, note: note || null, startsAt: when ? new Date(when).toISOString() : null } }),
                  'Grupo publicado: la hermandad ya puede unirse',
                ).then(() => setOpen(false));
              }}
            >
              <button type="button" onClick={() => setOpen(false)} className="absolute right-2 top-2 grid h-9 w-9 place-items-center text-fg-3 hover:text-fg" aria-label="Cerrar formulario">
                <X className="h-4 w-4" aria-hidden />
              </button>
              <div className="space-y-1.5">
                <label htmlFor="g-dungeon" className="label">Mazmorra</label>
                <select id="g-dungeon" className="field" value={dungeon} onChange={(e) => setDungeon(e.target.value)}>
                  {DUNGEONS.map((d) => (
                    <option key={d.key} value={d.key}>
                      {d.nameEs} ({d.min}–{d.max})
                    </option>
                  ))}
                </select>
              </div>
              <div className="space-y-1.5">
                <label htmlFor="g-char" className="label">Tu personaje</label>
                <select id="g-char" className="field" value={charId} onChange={(e) => setCharId(e.target.value)}>
                  {myChars.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.displayName} (nivel {c.level})
                    </option>
                  ))}
                </select>
              </div>
              <div className="space-y-1.5">
                <label htmlFor="g-role" className="label">Tu rol</label>
                <select id="g-role" className="field" value={role} onChange={(e) => setRole(e.target.value as CombatRole)}>
                  {roles.map((r) => (
                    <option key={r} value={r}>
                      {ROLE_LABEL[r]}
                    </option>
                  ))}
                </select>
              </div>
              <div className="space-y-1.5">
                <label htmlFor="g-when" className="label">Cuándo (opcional)</label>
                <input id="g-when" type="datetime-local" className="field" value={when} onChange={(e) => setWhen(e.target.value)} />
              </div>
              <div className="space-y-1.5 sm:col-span-2 lg:col-span-3">
                <label htmlFor="g-note" className="label">Nota</label>
                <input id="g-note" className="field" maxLength={200} value={note} onChange={(e) => setNote(e.target.value)} placeholder="Por ejemplo: vamos a por la llave de Stratholme" />
              </div>
              <div className="flex items-end">
                <button type="submit" className="btn-primary w-full" disabled={busy || !charId}>
                  {busy ? 'Publicando…' : 'Publicar grupo'}
                </button>
              </div>
            </form>
          )}
          {!myChars.length && <p className="mt-2 text-sm text-fg-3">Necesitas un personaje de esta hermandad vinculado a tu cuenta para formar o unirte a grupos.</p>}
        </div>
      )}
      {msg && (
        <p role="status" className={cn('text-sm', msg.ok ? 'text-success' : 'text-danger')}>
          {msg.text}
        </p>
      )}

      {groups.length === 0 ? (
        <p className="text-sm text-fg-3">No hay grupos abiertos ahora mismo. Forma uno y avisaremos a la hermandad en esta página.</p>
      ) : (
        <ul className="grid gap-4 lg:grid-cols-2">
          {groups.map((g) => {
            const mine = g.members.some((m) => m.isViewer);
            const eligible = myChars.filter((c) => c.level >= g.dungeon.min - 3);
            return (
              <li key={g.id}>
                <article className="cinematic frame-gold relative isolate overflow-hidden rounded-[4px] p-4">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={zoneArt(g.dungeon.key)} alt="" aria-hidden className="absolute inset-0 -z-20 h-full w-full object-cover opacity-40" />
                  <span aria-hidden className="absolute inset-0 -z-10 bg-gradient-to-r from-[#07090d] via-[#07090d]/85 to-[#07090d]/50" />
                  <header className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <h3 className="t-display text-xl text-white">{g.dungeon.name}</h3>
                      <p className="t-num text-xs text-white/60">
                        Niveles {g.dungeon.min}–{g.dungeon.max}
                        {g.startsAt ? `, ${fmtDateTime(g.startsAt)}` : ', ya'}
                      </p>
                    </div>
                    <p className="flex gap-2 text-xs" aria-label="Plazas libres">
                      {(['TANK', 'HEALER', 'DPS'] as const).map((r) => {
                        const Icon = ROLE_ICON[r];
                        return (
                          <span key={r} className={cn('inline-flex items-center gap-1 rounded-full px-2 py-0.5 ring-1', g.needs[r] > 0 ? 'text-warning ring-warning/50' : 'text-white/40 ring-white/10')} title={`${ROLE_LABEL[r]}: faltan ${g.needs[r]}`}>
                            <Icon className="h-3 w-3" aria-hidden /> {g.needs[r]}
                          </span>
                        );
                      })}
                    </p>
                  </header>
                  {g.note && <p className="mt-2 text-sm text-white/75">{g.note}</p>}
                  <ul className="mt-3 flex flex-wrap gap-2">
                    {g.members.map((m) => {
                      const Icon = ROLE_ICON[m.role];
                      return (
                        <li key={m.userId} className="inline-flex items-center gap-1.5 rounded bg-black/45 px-2 py-1 text-xs ring-1 ring-white/10">
                          <ClassIcon classId={m.character.classId} size={18} />
                          <span className="font-semibold" style={{ color: classVar(m.character.classId) }}>
                            {m.character.displayName}
                          </span>
                          <Icon className="h-3 w-3 text-white/50" aria-label={ROLE_LABEL[m.role]} />
                        </li>
                      );
                    })}
                  </ul>
                  <footer className="mt-4 flex flex-wrap gap-2">
                    {!mine &&
                      eligible.length > 0 &&
                      (['TANK', 'HEALER', 'DPS'] as const)
                        .filter((r) => g.needs[r] > 0)
                        .map((r) => {
                          const pick = eligible.find((c) => classById(c.classId)?.roles.includes(r));
                          if (!pick) return null;
                          return (
                            <button key={r} type="button" disabled={busy} className="btn-secondary h-9 min-h-0 px-3 text-xs" onClick={() => act(() => clientApi(`/v1/groups/${g.id}/join`, { method: 'PUT', body: { characterId: pick.id, role: r } }), `Te has unido como ${ROLE_LABEL[r].toLowerCase()} con ${pick.displayName}`)}>
                              Unirme como {ROLE_LABEL[r].toLowerCase()} ({pick.displayName})
                            </button>
                          );
                        })}
                    {mine && !g.isLeader && (
                      <button type="button" disabled={busy} className="btn-ghost h-9 min-h-0 px-3 text-xs text-white/80" onClick={() => act(() => clientApi(`/v1/groups/${g.id}/join`, { method: 'DELETE' }), 'Has salido del grupo')}>
                        Salir del grupo
                      </button>
                    )}
                    {g.isLeader && (
                      <button type="button" disabled={busy} className="btn-ghost h-9 min-h-0 px-3 text-xs text-white/80" onClick={() => act(() => clientApi(`/v1/groups/${g.id}/close`, { method: 'POST', body: {} }), 'Grupo cerrado')}>
                        Cerrar grupo
                      </button>
                    )}
                  </footer>
                </article>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
