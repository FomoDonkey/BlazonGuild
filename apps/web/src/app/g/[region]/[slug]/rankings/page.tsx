import type { Metadata } from 'next';
import Link from 'next/link';
import { Lock } from 'lucide-react';
import type { RankingBoardDTO, RankingMetric } from '@blazonguild/types';
import { PageBanner } from '@/components/art/CinematicHero';
import { FiligreeCorner } from '@/components/art/Ornaments';
import { factionAtmosphere } from '@/components/art/raid-art';
import { ClassIcon, RoleIcon } from '@/components/game/bits';
import { EmptyState, ProvenanceNote } from '@/components/ui/states';
import { api, getGuildOverview, guildPath } from '@/lib/api';
import { fmtInt } from '@/lib/format';
import { characterHref, classById, classVar, guildHref, specById } from '@/lib/game';
import { cn } from '@/lib/utils';

type Props = { params: Promise<{ region: string; slug: string }>; searchParams: Promise<Record<string, string | undefined>> };

const METRICS: { key: RankingMetric; label: string; available: boolean }[] = [
  { key: 'level', label: 'Nivel', available: true },
  { key: 'item_level', label: 'Nivel de objeto', available: true },
  { key: 'honorable_kills', label: 'Muertes con honor', available: true },
  { key: 'profession_skill', label: 'Profesiones', available: true },
  { key: 'achievement_points', label: 'Logros', available: true },
  { key: 'dps', label: 'DPS', available: false },
  { key: 'hps', label: 'HPS', available: false },
  { key: 'attendance', label: 'Asistencia', available: false },
];

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug).catch(() => null);
  return { title: o ? `Rankings de ${o.guild.name}` : 'Rankings' };
}

export default async function RankingsPage({ params, searchParams }: Props) {
  const { region, slug } = await params;
  const sp = await searchParams;
  const metric = (METRICS.find((m) => m.key === sp.metric)?.key ?? 'level') as RankingMetric;
  const classId = sp.classId ? Number(sp.classId) : undefined;
  const role = sp.role === 'TANK' || sp.role === 'HEALER' || sp.role === 'DPS' ? sp.role : undefined;
  const q = new URLSearchParams();
  if (classId) q.set('classId', String(classId));
  if (role) q.set('role', role);
  const [overview, board] = await Promise.all([getGuildOverview(region, slug), api<RankingBoardDTO>(`${guildPath(region, slug)}/rankings/${metric}?${q}`)]);
  const base = guildHref(region, slug, '/rankings');
  const href = (patch: Record<string, string | undefined>) => {
    const next = new URLSearchParams();
    const merged = { metric, classId: classId ? String(classId) : undefined, role, ...patch };
    for (const [k, v] of Object.entries(merged)) if (v) next.set(k, v);
    return `${base}?${next}`;
  };
  const max = Math.max(1, ...board.entries.map((e) => e.value));
  const atmo = factionAtmosphere(overview.guild.faction);
  const podium = board.available ? board.entries.slice(0, 3) : [];
  const MEDAL = ['#f3d27a', '#d9dee6', '#d79a63'];

  return (
    <div>
      <PageBanner art={atmo.art} hue={atmo.hue} glow={atmo.glow} title="Rankings" subtitle={<>Clasificaciones internas de {overview.guild.name}, con metodología a la vista.</>}>
        {podium.length > 0 && (
          <ol className="mx-auto grid max-w-4xl grid-cols-3 items-end gap-3 px-4 pb-8 sm:gap-6" aria-label={`Podio: ${board.label}`}>
            {[podium[1], podium[0], podium[2]].map((e, i) =>
              e ? (
                <li key={e.member.characterId} className={cn('flex flex-col items-center', i === 1 ? 'order-2' : i === 0 ? 'order-1' : 'order-3')} style={{ ['--cls' as string]: classVar(e.member.classId) }}>
                  <Link href={characterHref(e.member.region, e.member.slug)} className={cn('group relative block w-full', i === 1 ? 'h-56 sm:h-72' : 'h-44 sm:h-56')}>
                    {e.member.renderUrl && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={e.member.renderUrl} alt="" className="glow-class absolute inset-0 h-full w-full object-cover transition-transform duration-500 group-hover:-translate-y-1" style={{ objectPosition: '50% 56%', transform: 'scale(1.6)' }} />
                    )}
                  </Link>
                  <div className="plate relative -mt-3 w-full rounded-[3px] px-3 py-2.5 text-center">
                    <FiligreeCorner id={`pod${i}a`} size={16} className="pointer-events-none absolute left-0.5 top-0.5" />
                    <FiligreeCorner id={`pod${i}b`} size={16} className="pointer-events-none absolute bottom-0.5 right-0.5 -scale-100" />
                    <p className="t-figure text-2xl" style={{ color: MEDAL[e.position - 1] ?? '#f3e2b6' }}>{e.position}º</p>
                    <p className="truncate text-sm font-semibold" style={{ color: classVar(e.member.classId) }}>{e.member.displayName}</p>
                    <p className="t-num text-xs text-white/60">{fmtInt(e.value)} {board.unit}</p>
                  </div>
                </li>
              ) : null,
            )}
          </ol>
        )}
      </PageBanner>
      <div className="mx-auto max-w-7xl px-4 pb-10 sm:px-6">

      <nav aria-label="Métrica" className="scrollbar-thin -mx-4 mt-6 overflow-x-auto px-4 sm:mx-0 sm:px-0">
        <ul className="flex min-w-max gap-1 border-b border-line">
          {METRICS.map((m) => {
            const on = m.key === metric;
            return (
              <li key={m.key}>
                <Link
                  href={href({ metric: m.key })}
                  aria-current={on ? 'page' : undefined}
                  className={cn('relative flex h-11 items-center gap-1.5 px-3 text-sm', on ? 'text-fg' : 'text-fg-2 hover:text-fg', !m.available && 'text-fg-3')}
                >
                  {!m.available && <Lock className="h-3.5 w-3.5" aria-label="No disponible todavía" />}
                  {m.label}
                  {on && <span aria-hidden className="absolute inset-x-2 -bottom-px h-0.5 bg-accent" />}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      <div className="mt-4 flex flex-wrap items-center gap-1.5">
        <Link href={href({ classId: undefined })} className={cn('flex h-9 items-center rounded-full border px-3 text-sm', !classId ? 'border-accent text-fg' : 'border-line text-fg-2 hover:border-line-strong')}>
          Todas las clases
        </Link>
        {overview.stats.classDistribution.map((c) => {
          const id = Number(c.key);
          const on = classId === id;
          return (
            <Link key={c.key} href={href({ classId: on ? undefined : String(id) })} aria-current={on ? 'true' : undefined} className={cn('flex h-9 items-center gap-2 rounded-full border px-2.5 pr-3 text-sm', on ? 'bg-elevated text-fg' : 'border-line text-fg-2 hover:border-line-strong')} style={on ? { borderColor: classVar(id) } : undefined}>
              <ClassIcon classId={id} size={20} className="rounded-full" />
              {c.label}
            </Link>
          );
        })}
        <span className="mx-2 hidden h-6 w-px bg-line sm:block" aria-hidden />
        {(['TANK', 'HEALER', 'DPS'] as const).map((r) => (
          <Link key={r} href={href({ role: role === r ? undefined : r })} className={cn('flex h-9 items-center gap-1.5 rounded-full border px-3 text-sm', role === r ? 'border-accent bg-elevated text-fg' : 'border-line text-fg-2 hover:border-line-strong')} title="Rol estimado por la rama con más talentos">
            <RoleIcon role={r} />
            {r === 'TANK' ? 'Tanques' : r === 'HEALER' ? 'Sanadores' : 'Daño'}
          </Link>
        ))}
      </div>

      <div className="mt-6 grid gap-8 lg:grid-cols-[minmax(0,1fr)_300px]">
        <section aria-labelledby="board">
          <h2 id="board" className="sr-only">
            {board.label}
          </h2>
          {!board.available ? (
            <EmptyState icon={Lock} title={`${board.label}: todavía no disponible`}>
              {board.unavailableReason}
            </EmptyState>
          ) : board.entries.length === 0 ? (
            <EmptyState title="Nadie cumple los criterios">Cambia la clase o el rol, o espera a que terminen de sincronizarse los perfiles.</EmptyState>
          ) : (
            <div className="overflow-hidden rounded-md border border-line">
              <table className="w-full border-collapse text-sm">
                <caption className="sr-only">{board.label}</caption>
                <thead className="bg-sunken text-left text-xs text-fg-2">
                  <tr className="border-b border-line">
                    <th scope="col" className="w-14 px-3 py-2.5 text-right font-medium">
                      Pos.
                    </th>
                    <th scope="col" className="px-3 py-2.5 font-medium">
                      Personaje
                    </th>
                    <th scope="col" className="hidden px-3 py-2.5 font-medium sm:table-cell">
                      Clase y rama
                    </th>
                    <th scope="col" className="px-3 py-2.5 text-right font-medium">
                      {board.unit}
                    </th>
                    <th scope="col" className="hidden w-[28%] px-3 py-2.5 font-medium md:table-cell">
                      <span className="sr-only">Comparativa</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {board.entries.map((e) => {
                    const m = e.member;
                    const spec = specById(m.primarySpecId);
                    const podium = e.position <= 3;
                    return (
                      <tr key={m.characterId} className="border-b border-line/70 last:border-0 hover:bg-elevated/40">
                        <td className={cn('t-num px-3 py-2 text-right', podium ? 'text-lg font-semibold text-accent' : 'text-fg-3')}>{e.position}</td>
                        <td className="px-3 py-2">
                          <Link href={characterHref(m.region, m.slug)} className="flex items-center gap-2.5">
                            <ClassIcon classId={m.classId} size={24} />
                            <span className="font-semibold hover:underline" style={{ color: classVar(m.classId) }}>
                              {m.displayName}
                            </span>
                          </Link>
                        </td>
                        <td className="hidden px-3 py-2 text-fg-2 sm:table-cell">
                          {classById(m.classId)?.nameEs}
                          {spec && <span className="text-fg-3">, {spec.nameEs}</span>}
                        </td>
                        <td className="t-num px-3 py-2 text-right font-semibold text-fg">
                          {fmtInt(e.value)}
                          {e.detail && <span className="block text-xs font-normal text-fg-3">{e.detail}</span>}
                        </td>
                        <td className="hidden px-3 py-2 md:table-cell" aria-hidden>
                          <span className="block h-1.5 rounded-r-[4px] bg-sunken">
                            <span className="block h-full rounded-r-[4px]" style={{ width: `${(e.value / max) * 100}%`, background: classVar(m.classId) }} />
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <aside aria-labelledby="method" className="space-y-4">
          <h2 id="method" className="t-display text-lg">
            Metodología
          </h2>
          <dl className="space-y-3 text-sm">
            {[
              ['Métrica', board.label],
              ['Cálculo', board.methodology.calculation],
              ['Periodo', board.methodology.period],
              ['Elegibilidad', board.methodology.eligibility],
              ['Fuente', board.methodology.source],
              ['Verificación', board.methodology.verification],
              ['Orden', board.methodology.sorting],
            ].map(([k, v]) => (
              <div key={k}>
                <dt className="text-xs text-fg-3">{k}</dt>
                <dd className="text-fg-2">{v}</dd>
              </div>
            ))}
            <div>
              <dt className="text-xs text-fg-3">Muestra</dt>
              <dd className="t-num text-fg-2">
                {board.available ? `${fmtInt(board.sampleSize)} de ${fmtInt(board.eligibleTotal)} personajes` : '—'}
              </dd>
            </div>
          </dl>
          <ProvenanceNote provenance={board.provenance} />
          <p className="text-xs text-fg-3">No se usan percentiles: con muestras de una sola hermandad no serían estadísticamente defendibles.</p>
        </aside>
      </div>
      </div>
    </div>
  );
}
