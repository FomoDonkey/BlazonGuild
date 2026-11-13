'use client';

import Link from 'next/link';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useEffect, useMemo, useState, useTransition } from 'react';
import { ArrowDown, ArrowUp, Columns3, LayoutGrid, Loader2, Rows3, Search, SlidersHorizontal, X } from 'lucide-react';
import type { DistributionBucket, Page, RosterMemberDTO, RosterSortKey } from '@blazonguild/types';
import { ClassIcon, RoleIcon, TalentSplit } from '@/components/game/bits';
import { EmptyState } from '@/components/ui/states';
import { fmtInt, relativeTime } from '@/lib/format';
import { characterHref, classById, classVar, raceById, specById } from '@/lib/game';
import { cn } from '@/lib/utils';

type ColumnKey = 'level' | 'race' | 'rank' | 'spec' | 'talents' | 'itemLevel' | 'honorableKills' | 'lastLogin';
const COLUMNS: { key: ColumnKey; label: string; sort?: RosterSortKey; numeric?: boolean; defaultOn: boolean }[] = [
  { key: 'level', label: 'Nivel', sort: 'level', numeric: true, defaultOn: true },
  { key: 'race', label: 'Raza', defaultOn: false },
  { key: 'rank', label: 'Rango', sort: 'rank', defaultOn: true },
  { key: 'spec', label: 'Rama principal', defaultOn: true },
  { key: 'talents', label: 'Talentos', defaultOn: true },
  { key: 'itemLevel', label: 'iLvl', sort: 'itemLevel', numeric: true, defaultOn: true },
  { key: 'honorableKills', label: 'MCH', sort: 'honorableKills', numeric: true, defaultOn: false },
  { key: 'lastLogin', label: 'Última conexión', sort: 'lastLogin', defaultOn: true },
];
const STORAGE_KEY = 'forever-roster-columns';

function rankLabel(m: RosterMemberDTO) {
  if (m.rankName) return m.rankName;
  if (m.rankIndex === 0) return 'Maestro';
  return m.rankIndex >= 0 ? `Rango ${m.rankIndex}` : '—';
}

function useColumns() {
  const [on, setOn] = useState<Set<ColumnKey>>(() => new Set(COLUMNS.filter((c) => c.defaultOn).map((c) => c.key)));
  useEffect(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? 'null');
      if (Array.isArray(saved)) setOn(new Set(saved));
    } catch {
      /* ignore */
    }
  }, []);
  const toggle = (k: ColumnKey) =>
    setOn((prev) => {
      const next = new Set(prev);
      if (next.has(k)) next.delete(k);
      else next.add(k);
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify([...next]));
      } catch {
        /* ignore */
      }
      return next;
    });
  return { on, toggle };
}

export function RosterView({
  region,
  slug,
  view,
  page,
  ranks,
  classes,
}: {
  region: string;
  slug: string;
  view: 'table' | 'directory';
  page: Page<RosterMemberDTO>;
  ranks: DistributionBucket[];
  classes: DistributionBucket[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [pending, startTransition] = useTransition();
  const [q, setQ] = useState(params.get('q') ?? '');
  const [colsOpen, setColsOpen] = useState(false);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const { on, toggle } = useColumns();

  const update = (patch: Record<string, string | null>) => {
    const next = new URLSearchParams(params.toString());
    for (const [k, v] of Object.entries(patch)) {
      if (v === null || v === '') next.delete(k);
      else next.set(k, v);
    }
    startTransition(() => router.replace(`${pathname}?${next.toString()}`, { scroll: false }));
  };

  useEffect(() => {
    const t = setTimeout(() => {
      if ((params.get('q') ?? '') !== q) update({ q: q || null });
    }, 250);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q]);

  const selectedClasses = useMemo(() => new Set((params.get('classIds') ?? '').split(',').filter(Boolean).map(Number)), [params]);
  const sort = (params.get('sort') as RosterSortKey | null) ?? 'rank';
  const dir = params.get('dir') ?? (sort === 'rank' || sort === 'name' ? 'asc' : 'desc');
  const activeFilters = ['q', 'classIds', 'ranks', 'role', 'minLevel', 'activeDays'].filter((k) => params.get(k)).length;

  const toggleClass = (id: number) => {
    const next = new Set(selectedClasses);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    update({ classIds: next.size ? [...next].join(',') : null });
  };
  const setSort = (key: RosterSortKey) => {
    const nextDir = sort === key ? (dir === 'asc' ? 'desc' : 'asc') : key === 'rank' || key === 'name' ? 'asc' : 'desc';
    update({ sort: key, dir: nextDir });
  };
  const columns = COLUMNS.filter((c) => on.has(c.key));
  const members = page.items;

  return (
    <div className="mt-6">
      {/* Filters: one row, adapts to narrow screens */}
      <div className="flex flex-col gap-3 border-b border-line pb-4">
        <div className="flex flex-wrap items-center gap-2">
          <div className="relative min-w-[200px] flex-1 sm:max-w-xs">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-fg-3" aria-hidden />
            <label htmlFor="roster-q" className="sr-only">
              Buscar por nombre
            </label>
            <input id="roster-q" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Buscar por nombre" className="field pl-9" />
          </div>
          <button type="button" onClick={() => setFiltersOpen((o) => !o)} aria-expanded={filtersOpen} aria-controls="roster-filters" className="btn-secondary h-10 min-h-0 px-3 md:hidden">
            <SlidersHorizontal className="h-4 w-4" aria-hidden /> Filtros{activeFilters > 0 ? ` (${activeFilters})` : ''}
          </button>
          <div id="roster-filters" className={cn('w-full flex-wrap items-center gap-2 md:flex md:w-auto', filtersOpen ? 'flex' : 'hidden')}>
          <label className="sr-only" htmlFor="roster-rank">
            Rango
          </label>
          <select id="roster-rank" className="field w-auto" value={params.get('ranks') ?? ''} onChange={(e) => update({ ranks: e.target.value || null })}>
            <option value="">Todos los rangos</option>
            {ranks.map((r) => (
              <option key={r.key} value={r.key}>
                {r.label} ({r.count})
              </option>
            ))}
          </select>
          <label className="sr-only" htmlFor="roster-level">
            Nivel
          </label>
          <select
            id="roster-level"
            className="field w-auto"
            value={params.get('minLevel') ?? ''}
            onChange={(e) => {
              const v = e.target.value;
              if (!v) return update({ minLevel: null, maxLevel: null });
              const [min, max] = v.split('-');
              update({ minLevel: min, maxLevel: max });
            }}
          >
            <option value="">Todos los niveles</option>
            <option value="1-19">1–19</option>
            <option value="20-39">20–39</option>
            <option value="40-59">40–59</option>
            <option value="60-60">60</option>
          </select>
          <label className="sr-only" htmlFor="roster-active">
            Actividad
          </label>
          <select id="roster-active" className="field w-auto" value={params.get('activeDays') ?? ''} onChange={(e) => update({ activeDays: e.target.value || null })}>
            <option value="">Cualquier actividad</option>
            <option value="1">Conectados hoy</option>
            <option value="7">Últimos 7 días</option>
            <option value="30">Últimos 30 días</option>
          </select>
          <label className="sr-only" htmlFor="roster-role">
            Rol estimado
          </label>
          <select id="roster-role" className="field w-auto" value={params.get('role') ?? ''} onChange={(e) => update({ role: e.target.value || null })} title="Estimado por la rama con más talentos">
            <option value="">Cualquier rol</option>
            <option value="TANK">Tanque (estimado)</option>
            <option value="HEALER">Sanador (estimado)</option>
            <option value="DPS">Daño (estimado)</option>
          </select>
          </div>

          <div className="ml-auto flex items-center gap-1">
            {pending && <Loader2 className="mr-1 h-4 w-4 animate-spin text-fg-3" aria-label="Actualizando" />}
            <div role="group" aria-label="Vista" className="flex rounded border border-line bg-sunken p-0.5">
              <button type="button" onClick={() => update({ view: null })} aria-pressed={view === 'table'} className={cn('flex h-9 items-center gap-1.5 rounded-sm px-2.5 text-sm', view === 'table' ? 'bg-elevated text-fg' : 'text-fg-2')}>
                <Rows3 className="h-4 w-4" aria-hidden /> <span className="hidden sm:inline">Tabla</span>
              </button>
              <button type="button" onClick={() => update({ view: 'directory' })} aria-pressed={view === 'directory'} className={cn('flex h-9 items-center gap-1.5 rounded-sm px-2.5 text-sm', view === 'directory' ? 'bg-elevated text-fg' : 'text-fg-2')}>
                <LayoutGrid className="h-4 w-4" aria-hidden /> <span className="hidden sm:inline">Directorio</span>
              </button>
            </div>
            {view === 'table' && (
              <div className="relative hidden md:block">
                <button type="button" onClick={() => setColsOpen((o) => !o)} aria-expanded={colsOpen} className="btn-ghost h-10 min-h-0 px-2.5" aria-label="Elegir columnas">
                  <Columns3 className="h-4 w-4" aria-hidden />
                </button>
                {colsOpen && (
                  <fieldset className="absolute right-0 top-11 z-30 w-56 rounded-md border border-line-strong bg-surface p-3 shadow-tooltip">
                    <legend className="sr-only">Columnas visibles</legend>
                    {COLUMNS.map((c) => (
                      <label key={c.key} className="flex min-h-[34px] cursor-pointer items-center gap-2.5 text-sm">
                        <input type="checkbox" checked={on.has(c.key)} onChange={() => toggle(c.key)} className="h-4 w-4 accent-[rgb(var(--c-accent))]" />
                        {c.label}
                      </label>
                    ))}
                  </fieldset>
                )}
              </div>
            )}
          </div>
        </div>

        <div className={cn('flex-wrap items-center gap-1.5 md:flex', filtersOpen ? 'flex' : 'hidden')} role="group" aria-label="Filtrar por clase">
          {classes.map((c) => {
            const id = Number(c.key);
            const selected = selectedClasses.has(id);
            return (
              <button
                key={c.key}
                type="button"
                aria-pressed={selected}
                onClick={() => toggleClass(id)}
                className={cn('flex h-9 items-center gap-2 rounded-full border px-2.5 pr-3 text-sm transition-colors', selected ? 'border-[color:var(--cls)] bg-elevated text-fg' : 'border-line text-fg-2 hover:border-line-strong')}
                style={{ ['--cls' as string]: classVar(id) }}
              >
                <ClassIcon classId={id} size={20} className="rounded-full" />
                {c.label}
                <span className="t-num text-xs text-fg-3">{c.count}</span>
              </button>
            );
          })}
          {activeFilters > 0 && (
            <button type="button" onClick={() => { setQ(''); update({ q: null, classIds: null, ranks: null, role: null, minLevel: null, maxLevel: null, activeDays: null }); }} className="ml-1 flex h-9 items-center gap-1 rounded px-2 text-sm text-accent hover:underline">
              <X className="h-3.5 w-3.5" aria-hidden /> Quitar filtros
            </button>
          )}
        </div>
      </div>

      <p className="mt-3 text-sm text-fg-3" aria-live="polite">
        {page.total === members.length ? `${fmtInt(page.total)} personajes` : `${fmtInt(members.length)} de ${fmtInt(page.total)} personajes`}
      </p>

      {members.length === 0 ? (
        <EmptyState className="mt-4" title="Ningún personaje coincide con estos filtros">
          Prueba a quitar algún filtro o a buscar por otra parte del nombre.
        </EmptyState>
      ) : view === 'directory' ? (
        <ul className={cn('mt-4 grid grid-cols-2 gap-3 transition-opacity sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5', pending && 'opacity-60')}>
          {members.map((m) => (
            <li key={m.characterId}>
              <Link href={characterHref(m.region, m.slug)} className="group block overflow-hidden rounded-md border border-line bg-surface hover:border-[color:var(--cls)]" style={{ ['--cls' as string]: classVar(m.classId) }}>
                <div className="relative aspect-square bg-sunken">
                  {m.avatarUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={m.avatarUrl} alt="" loading="lazy" className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-[1.03]" />
                  ) : (
                    <span className="grid h-full place-items-center">
                      <ClassIcon classId={m.classId} size={48} />
                    </span>
                  )}
                  <span className="t-num absolute bottom-2 left-2 rounded-sm bg-black/70 px-1.5 py-0.5 text-xs font-semibold text-white">{m.level}</span>
                </div>
                <div className="space-y-0.5 p-3">
                  <p className="truncate font-semibold" style={{ color: classVar(m.classId) }}>
                    {m.displayName}
                  </p>
                  <p className="truncate text-xs text-fg-2">
                    {specById(m.primarySpecId)?.nameEs ?? classById(m.classId)?.nameEs}, {rankLabel(m)}
                  </p>
                </div>
              </Link>
            </li>
          ))}
        </ul>
      ) : (
        <>
          {/* Mobile: readable list instead of a squeezed table */}
          <ul className={cn('mt-3 divide-y divide-line border-y border-line md:hidden', pending && 'opacity-60')}>
            {members.map((m) => (
              <li key={m.characterId}>
                <Link href={characterHref(m.region, m.slug)} className="flex items-center gap-3 py-3">
                  <ClassIcon classId={m.classId} size={36} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-semibold" style={{ color: classVar(m.classId) }}>
                      {m.displayName}
                    </span>
                    <span className="block truncate text-xs text-fg-2">
                      {rankLabel(m)}
                      {m.lastLoginAt ? `, ${relativeTime(m.lastLoginAt)}` : ''}
                    </span>
                  </span>
                  <span className="text-right">
                    <span className="t-num block font-semibold">{m.level}</span>
                    <span className="t-num block text-xs text-fg-3">{m.itemLevel ? `iLvl ${m.itemLevel}` : 'nivel'}</span>
                  </span>
                </Link>
              </li>
            ))}
          </ul>

          <div className={cn('mt-3 hidden overflow-x-auto rounded-md border border-line md:block', pending && 'opacity-60')}>
            <table className="w-full min-w-[720px] border-collapse text-sm">
              <caption className="sr-only">Roster de la hermandad</caption>
              <thead className="bg-sunken">
                <tr className="border-b border-line text-left text-xs text-fg-2">
                  <th scope="col" aria-sort={sort === 'name' ? (dir === 'asc' ? 'ascending' : 'descending') : undefined} className="px-4 py-2.5 font-medium">
                    <SortButton label="Personaje" active={sort === 'name'} dir={dir} onClick={() => setSort('name')} />
                  </th>
                  {columns.map((c) => (
                    <th key={c.key} scope="col" aria-sort={c.sort && sort === c.sort ? (dir === 'asc' ? 'ascending' : 'descending') : undefined} className={cn('px-3 py-2.5 font-medium', c.numeric && 'text-right')}>
                      {c.sort ? <SortButton label={c.label} active={sort === c.sort} dir={dir} onClick={() => setSort(c.sort!)} align={c.numeric ? 'right' : 'left'} /> : c.label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {members.map((m) => (
                  <tr key={m.characterId} className="border-b border-line/70 last:border-0 hover:bg-elevated/40">
                    <td className="px-4 py-2">
                      <Link href={characterHref(m.region, m.slug)} className="flex items-center gap-2.5">
                        <ClassIcon classId={m.classId} size={24} />
                        <span className="font-semibold hover:underline" style={{ color: classVar(m.classId) }}>
                          {m.displayName}
                        </span>
                        {m.claimed && <span className="rounded-sm border border-line px-1 text-2xs text-fg-3" title="Vinculado a una cuenta de BlazonGuild">cuenta</span>}
                      </Link>
                    </td>
                    {columns.map((c) => (
                      <td key={c.key} className={cn('px-3 py-2 text-fg-2', c.numeric && 't-num text-right text-fg')}>
                        {c.key === 'level' && m.level}
                        {c.key === 'race' && (raceById(m.raceId)?.nameEs ?? '—')}
                        {c.key === 'rank' && rankLabel(m)}
                        {c.key === 'spec' && (
                          <span className="inline-flex items-center gap-1.5">
                            <RoleIcon role={m.roleHint} className="text-fg-3" />
                            {specById(m.primarySpecId)?.nameEs ?? <span className="text-fg-3">—</span>}
                          </span>
                        )}
                        {c.key === 'talents' && <TalentSplit split={m.talentSplit} />}
                        {c.key === 'itemLevel' && (m.itemLevel ?? <span className="text-fg-3">—</span>)}
                        {c.key === 'honorableKills' && (m.honorableKills ?? <span className="text-fg-3">—</span>)}
                        {c.key === 'lastLogin' && (m.lastLoginAt ? <time dateTime={m.lastLoginAt}>{relativeTime(m.lastLoginAt)}</time> : <span className="text-fg-3">Perfil no público</span>)}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-xs text-fg-3">El rol se estima a partir de la rama con más talentos; no lo declara el jugador.</p>
        </>
      )}
    </div>
  );
}

function SortButton({ label, active, dir, onClick, align = 'left' }: { label: string; active: boolean; dir: string; onClick: () => void; align?: 'left' | 'right' }) {
  return (
    <button type="button" onClick={onClick} className={cn('inline-flex items-center gap-1 hover:text-fg', active && 'text-fg', align === 'right' && 'flex-row-reverse')}>
      {label}
      {active ? dir === 'asc' ? <ArrowUp className="h-3 w-3" aria-hidden /> : <ArrowDown className="h-3 w-3" aria-hidden /> : <span className="w-3" />}
    </button>
  );
}
