'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { DndContext, PointerSensor, useDraggable, useDroppable, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core';
import { AlertTriangle, Check, Info, Save, Undo2 } from 'lucide-react';
import type { CombatRole, RaidDetailDTO, RaidSignupDTO, SignupStatus } from '@blazonguild/types';
import { ClassIcon, RoleIcon } from '@/components/game/bits';
import { clientApi, ClientApiError } from '@/lib/client-api';
import { CLASSES, classById, classVar, ROLE_LABEL } from '@/lib/game';
import { cn } from '@/lib/utils';

type Pos = { group: number | null; slot: number | null; status: SignupStatus; role: CombatRole };
type Layout = Record<string, Pos>;

const BUFF_CLASSES: { classId: number; buff: string }[] = [
  { classId: 5, buff: 'Palabra de poder: entereza' },
  { classId: 8, buff: 'Intelecto Arcano' },
  { classId: 11, buff: 'Marca de lo Salvaje' },
  { classId: 2, buff: 'Bendiciones de paladín' },
  { classId: 7, buff: 'Tótems de chamán' },
  { classId: 9, buff: 'Piedras de salud y maldiciones' },
];

function initialLayout(signups: RaidSignupDTO[]): Layout {
  return Object.fromEntries(signups.map((s) => [s.id, { group: s.group, slot: s.slot, status: s.status, role: s.role }]));
}

function Chip({ s, pos, selected, onSelect }: { s: RaidSignupDTO; pos: Pos; selected: boolean; onSelect: () => void }) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({ id: s.id });
  return (
    <button
      ref={setNodeRef}
      type="button"
      {...listeners}
      {...attributes}
      onClick={onSelect}
      aria-pressed={selected}
      aria-label={`${s.character.displayName}, ${ROLE_LABEL[pos.role]}${selected ? ', seleccionado: elige un hueco' : ''}`}
      className={cn(
        'flex h-9 w-full min-w-0 items-center gap-2 rounded border bg-elevated px-2 text-left text-xs touch-none',
        selected ? 'border-accent ring-1 ring-accent' : 'border-line hover:border-line-strong',
        isDragging && 'z-50 opacity-80 shadow-tooltip',
        pos.status === 'TENTATIVE' && 'border-dashed',
      )}
      style={transform ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)` } : undefined}
    >
      <ClassIcon classId={s.character.classId} size={18} />
      <span className="min-w-0 flex-1 truncate font-semibold" style={{ color: classVar(s.character.classId) }}>
        {s.character.displayName}
      </span>
      <RoleIcon role={pos.role} className="text-fg-3" />
    </button>
  );
}

function SlotCell({ id, children, onPlace, armed }: { id: string; children?: React.ReactNode; onPlace: () => void; armed: boolean }) {
  const { isOver, setNodeRef } = useDroppable({ id });
  return (
    <div ref={setNodeRef} className={cn('min-h-[36px] rounded', isOver && 'bg-accent/15 ring-1 ring-accent/60')}>
      {children ?? (
        <button type="button" onClick={onPlace} disabled={!armed} className={cn('h-9 w-full rounded border border-dashed text-2xs', armed ? 'border-accent/70 text-accent hover:bg-accent/10' : 'border-line/70 text-fg-3')} aria-label={armed ? 'Colocar aquí' : 'Hueco libre'}>
          {armed ? 'Colocar aquí' : ''}
        </button>
      )}
    </div>
  );
}

function Bucket({ id, title, children, onPlace, armed, hint }: { id: string; title: string; children: React.ReactNode; onPlace: () => void; armed: boolean; hint?: string }) {
  const { isOver, setNodeRef } = useDroppable({ id });
  return (
    <section ref={setNodeRef} aria-label={title} className={cn('rounded-md border border-line bg-surface p-3', isOver && 'ring-1 ring-accent/60')}>
      <div className="mb-2 flex items-center justify-between">
        <h3 className="text-sm font-medium">{title}</h3>
        {armed && (
          <button type="button" onClick={onPlace} className="text-xs text-accent hover:underline">
            Mover aquí
          </button>
        )}
      </div>
      {hint && <p className="mb-2 text-xs text-fg-3">{hint}</p>}
      <div className="space-y-1.5">{children}</div>
    </section>
  );
}

export function RaidPlanner({ raid, canManage }: { raid: RaidDetailDTO; canManage: boolean }) {
  const router = useRouter();
  const [layout, setLayout] = useState<Layout>(() => initialLayout(raid.signups));
  const [selected, setSelected] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ kind: 'ok' | 'error'; text: string } | null>(null);
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));
  // dnd-kit generates non-deterministic aria ids: enable dragging only after hydration.
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  const interactive = canManage && mounted;
  const groups = Math.ceil(raid.capacity / 5);
  const byId = new Map(raid.signups.map((s) => [s.id, s]));
  const dirty = raid.signups.some((s) => {
    const p = layout[s.id];
    return p.group !== s.group || p.slot !== s.slot || p.status !== s.status || p.role !== s.role;
  });

  const occupant = (g: number, slot: number) => Object.entries(layout).find(([, p]) => p.group === g && p.slot === slot)?.[0];

  const move = (id: string, target: string) => {
    if (!canManage) return;
    setLayout((prev) => {
      const next = { ...prev };
      const cur = next[id];
      if (target.startsWith('slot:')) {
        const [, g, sl] = target.split(':').map(Number);
        const other = Object.entries(next).find(([k, p]) => k !== id && p.group === g && p.slot === sl)?.[0];
        if (other) next[other] = { ...next[other], group: cur.group, slot: cur.slot, status: cur.group === null ? 'BENCHED' : next[other].status };
        next[id] = { ...cur, group: g, slot: sl, status: cur.status === 'BENCHED' || cur.status === 'TENTATIVE' ? 'CONFIRMED' : cur.status };
      } else if (target === 'bench') {
        next[id] = { ...cur, group: null, slot: null, status: 'BENCHED' };
      }
      return next;
    });
    setSelected(null);
    setMessage(null);
  };

  const onDragEnd = (e: DragEndEvent) => {
    if (e.over) move(String(e.active.id), String(e.over.id));
  };

  const placed = raid.signups.filter((s) => layout[s.id].group !== null);
  const bench = raid.signups.filter((s) => layout[s.id].group === null && layout[s.id].status !== 'DECLINED');
  const declined = raid.signups.filter((s) => layout[s.id].status === 'DECLINED');

  const analysis = useMemo(() => {
    const roles: Record<CombatRole, number> = { TANK: 0, HEALER: 0, DPS: 0 };
    const classes = new Map<number, number>();
    for (const s of placed) {
      roles[layout[s.id].role]++;
      classes.set(s.character.classId, (classes.get(s.character.classId) ?? 0) + 1);
    }
    const warnings: string[] = [];
    if (placed.length > 0) {
      if (roles.TANK === 0) warnings.push('No hay ningún tanque colocado en los grupos.');
      const healerShare = roles.HEALER / placed.length;
      if (placed.length >= 10 && healerShare < 0.2) warnings.push(`Solo ${roles.HEALER} sanadores para ${placed.length} jugadores (orientativo: 1 de cada 4 o 5).`);
      for (let g = 1; g <= groups; g++) {
        const members = placed.filter((s) => layout[s.id].group === g);
        if (members.length >= 3 && !members.some((s) => layout[s.id].role === 'HEALER')) warnings.push(`El grupo ${g} no tiene sanador.`);
      }
      for (const b of BUFF_CLASSES) if (placed.length >= 10 && !classes.has(b.classId)) warnings.push(`Falta ${classById(b.classId)?.nameEs.toLowerCase()}: sin ${b.buff}.`);
    }
    return { roles, classes, warnings };
  }, [placed, layout, groups]);

  const save = async () => {
    setSaving(true);
    setMessage(null);
    try {
      const assignments = raid.signups.map((s) => ({ signupId: s.id, group: layout[s.id].group, slot: layout[s.id].slot, status: layout[s.id].status, role: layout[s.id].role }));
      await clientApi(`/v1/raids/${raid.id}/composition`, { method: 'PUT', body: { assignments } });
      setMessage({ kind: 'ok', text: 'Composición guardada' });
      router.refresh();
    } catch (err) {
      setMessage({ kind: 'error', text: err instanceof ClientApiError ? err.message : 'No se pudo guardar' });
    } finally {
      setSaving(false);
    }
  };

  const chip = (s: RaidSignupDTO) =>
    interactive ? (
      <Chip key={s.id} s={s} pos={layout[s.id]} selected={selected === s.id} onSelect={() => setSelected((cur) => (cur === s.id ? null : s.id))} />
    ) : (
      <div key={s.id} className="flex h-9 items-center gap-2 rounded border border-line bg-elevated px-2 text-xs">
        <ClassIcon classId={s.character.classId} size={18} />
        <span className="min-w-0 flex-1 truncate font-semibold" style={{ color: classVar(s.character.classId) }}>
          {s.character.displayName}
        </span>
        <RoleIcon role={layout[s.id].role} className="text-fg-3" />
      </div>
    );

  return (
    <DndContext sensors={sensors} onDragEnd={onDragEnd}>
      <div className="space-y-6">
        <div className="space-y-4">
          {canManage && (
            <div className="flex flex-wrap items-center gap-2 rounded-md border border-line bg-sunken px-3 py-2 text-sm">
              <Info className="h-4 w-4 text-fg-3" aria-hidden />
              <span className="text-fg-2">Arrastra jugadores entre grupos, o pulsa uno y después el hueco de destino.</span>
              <span className="ml-auto flex items-center gap-2">
                {dirty && (
                  <button type="button" className="btn-ghost h-9 min-h-0 px-3" onClick={() => setLayout(initialLayout(raid.signups))}>
                    <Undo2 className="h-4 w-4" aria-hidden /> Descartar
                  </button>
                )}
                <button type="button" className="btn-primary h-9 min-h-0 px-3" disabled={!dirty || saving} onClick={save}>
                  <Save className="h-4 w-4" aria-hidden /> {saving ? 'Guardando…' : 'Guardar composición'}
                </button>
              </span>
            </div>
          )}
          {message && (
            <p role="status" className={cn('flex items-center gap-2 text-sm', message.kind === 'ok' ? 'text-success' : 'text-danger')}>
              {message.kind === 'ok' ? <Check className="h-4 w-4" aria-hidden /> : <AlertTriangle className="h-4 w-4" aria-hidden />}
              {message.text}
            </p>
          )}

          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {Array.from({ length: groups }, (_, gi) => {
              const g = gi + 1;
              return (
                <section key={g} aria-label={`Grupo ${g}`} className="rounded-md border border-line bg-surface p-2.5">
                  <h3 className="mb-2 flex items-center justify-between px-0.5 text-xs font-medium text-fg-2">
                    Grupo {g}
                    <span className="t-num text-fg-3">{[0, 1, 2, 3, 4].filter((sl) => occupant(g, sl)).length}/5</span>
                  </h3>
                  <div className="space-y-1.5">
                    {[0, 1, 2, 3, 4].map((sl) => {
                      const occ = occupant(g, sl);
                      return (
                        <SlotCell key={sl} id={`slot:${g}:${sl}`} armed={!!selected && interactive} onPlace={() => selected && move(selected, `slot:${g}:${sl}`)}>
                          {occ ? chip(byId.get(occ)!) : undefined}
                        </SlotCell>
                      );
                    })}
                  </div>
                </section>
              );
            })}
          </div>

          <div className="grid gap-3 md:grid-cols-2">
            <Bucket id="bench" title={`Sin asignar y banquillo (${bench.length})`} armed={!!selected && interactive} onPlace={() => selected && move(selected, 'bench')} hint="Inscritos que aún no están en un grupo. Los tentativos llevan borde discontinuo.">
              {bench.length ? bench.map(chip) : <p className="text-xs text-fg-3">Nadie pendiente.</p>}
            </Bucket>
            <Bucket id="declined" title={`No asisten (${declined.length})`} armed={false} onPlace={() => {}}>
              {declined.length ? declined.map((s) => <div key={s.id} className="truncate text-xs text-fg-3">{s.character.displayName}{s.comment ? `: ${s.comment}` : ''}</div>) : <p className="text-xs text-fg-3">Nadie ha rechazado.</p>}
            </Bucket>
          </div>
        </div>

        <aside className="grid gap-6 border-t border-line pt-6 md:grid-cols-3" aria-label="Análisis de composición">
          <section>
            <h3 className="t-display text-lg">Roles en grupos</h3>
            <dl className="mt-3 grid grid-cols-3 gap-2 text-center">
              {(['TANK', 'HEALER', 'DPS'] as const).map((r) => (
                <div key={r} className="rounded border border-line bg-surface py-2">
                  <dt className="flex items-center justify-center gap-1 text-xs text-fg-2">
                    <RoleIcon role={r} /> {ROLE_LABEL[r]}
                  </dt>
                  <dd className="t-figure text-2xl">{analysis.roles[r]}</dd>
                </div>
              ))}
            </dl>
            <p className="t-num mt-2 text-xs text-fg-3">
              {placed.length}/{raid.capacity} plazas ocupadas
            </p>
          </section>
          <section>
            <h3 className="t-display text-lg">Clases</h3>
            <ul className="mt-3 grid grid-cols-3 gap-2">
              {CLASSES.map((c) => (
                <li key={c.id} className={cn('flex items-center gap-1.5 text-xs', analysis.classes.get(c.id) ? 'text-fg' : 'text-fg-3 opacity-60')}>
                  <ClassIcon classId={c.id} size={18} />
                  <span className="t-num">{analysis.classes.get(c.id) ?? 0}</span>
                  <span className="sr-only">{c.nameEs}</span>
                </li>
              ))}
            </ul>
          </section>
          <section>
            <h3 className="t-display text-lg">Avisos</h3>
            {analysis.warnings.length ? (
              <ul className="mt-3 space-y-2">
                {analysis.warnings.map((w) => (
                  <li key={w} className="flex gap-2 text-sm text-fg-2">
                    <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-warning" aria-hidden />
                    {w}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="mt-3 text-sm text-fg-3">{placed.length ? 'Sin avisos para esta composición.' : 'Coloca jugadores para analizar la composición.'}</p>
            )}
            <p className="mt-3 text-xs text-fg-3">Reglas orientativas del juego clásico; no sustituyen el criterio del líder de banda.</p>
          </section>
        </aside>
      </div>
    </DndContext>
  );
}
