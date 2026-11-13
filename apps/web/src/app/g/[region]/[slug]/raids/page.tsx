import type { Metadata } from 'next';
import Link from 'next/link';
import { Lock, LogIn } from 'lucide-react';
import type { RaidSummaryDTO, ViewerContextDTO } from '@blazonguild/types';
import { PageBanner } from '@/components/art/CinematicHero';
import { factionAtmosphere, zoneArt } from '@/components/art/raid-art';
import { CreateRaidButton } from '@/components/raids/CreateRaid';
import { EmptyState } from '@/components/ui/states';
import { api, ApiFailure, getGuildOverview, guildPath } from '@/lib/api';
import { calendarParts, fmtDate, fmtTime } from '@/lib/format';
import { guildHref } from '@/lib/game';
import { cn } from '@/lib/utils';

type Props = { params: Promise<{ region: string; slug: string }>; searchParams: Promise<{ scope?: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug).catch(() => null);
  return { title: o ? `Raids de ${o.guild.name}` : 'Raids' };
}

const STATUS_LABEL = { SCHEDULED: 'Convocada', IN_PROGRESS: 'En curso', COMPLETED: 'Completada', CANCELLED: 'Cancelada' } as const;

function RaidRow({ r, base }: { r: RaidSummaryDTO; base: string }) {
  const c = calendarParts(r.startsAt);
  const filled = r.counts.confirmed / r.capacity;
  return (
    <li>
      <Link href={`${base}/${r.id}`} className="cinematic group relative isolate grid grid-cols-[3.5rem_minmax(0,1fr)] items-center gap-4 overflow-hidden px-4 py-5 sm:grid-cols-[3.5rem_minmax(0,1fr)_12rem_8rem]">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={zoneArt(r.instanceKey)} alt="" aria-hidden className="absolute inset-0 -z-20 h-full w-full object-cover opacity-50 transition-[transform,opacity] duration-700 group-hover:scale-105 group-hover:opacity-70" />
        <span aria-hidden className="absolute inset-0 -z-10 bg-gradient-to-r from-[#07090d] via-[#07090d]/85 to-[#07090d]/40" />
        <span className="plate grid rounded-[3px] py-1.5 text-center leading-none">
          <span className="text-2xs uppercase text-fg-3">{c.weekday}</span>
          <span className="t-figure text-3xl">{c.day}</span>
          <span className="text-2xs text-fg-3">{c.month}</span>
        </span>
        <span className="min-w-0">
          <span className="t-display block truncate text-lg text-white">{r.title}</span>
          <span className="block truncate text-sm text-fg-2">
            {r.instanceName}, {fmtTime(r.startsAt)}
            {r.leader && <span className="text-fg-3">. Lidera {r.leader}</span>}
          </span>
          {r.viewerSignup && <span className="mt-0.5 block text-xs text-success">Estás inscrito ({r.viewerSignup.status === 'CONFIRMED' ? 'confirmado' : r.viewerSignup.status === 'TENTATIVE' ? 'tentativo' : r.viewerSignup.status === 'BENCHED' ? 'banquillo' : 'no vas'})</span>}
        </span>
        <span className="col-span-2 sm:col-span-1">
          <span className="t-num flex justify-between text-xs text-fg-2">
            <span>
              {r.counts.confirmed}/{r.capacity} confirmados
            </span>
            <span className="text-fg-3">{r.counts.tentative} tentativos</span>
          </span>
          <span className="mt-1.5 block h-1.5 rounded-full bg-sunken" aria-hidden>
            <span className="block h-full rounded-full bg-success" style={{ width: `${Math.min(100, filled * 100)}%` }} />
          </span>
          <span className="t-num mt-1 block text-xs text-fg-3">
            {r.counts.roles.TANK} tanques, {r.counts.roles.HEALER} sanadores, {r.counts.roles.DPS} daño
          </span>
        </span>
        <span className={cn('hidden justify-self-end text-xs sm:block', r.status === 'CANCELLED' ? 'text-danger' : r.status === 'COMPLETED' ? 'text-fg-3' : 'text-success')}>{STATUS_LABEL[r.status]}</span>
      </Link>
    </li>
  );
}

export default async function RaidsPage({ params, searchParams }: Props) {
  const { region, slug } = await params;
  const { scope: rawScope } = await searchParams;
  const scope = rawScope === 'past' ? 'past' : 'upcoming';
  const overview = await getGuildOverview(region, slug);
  const base = guildHref(region, slug, '/raids');

  let data: { viewer: ViewerContextDTO; raids: RaidSummaryDTO[] } | null = null;
  let denied: number | null = null;
  try {
    data = await api(`${guildPath(region, slug)}/raids?scope=${scope}`);
  } catch (err) {
    if (err instanceof ApiFailure && (err.status === 401 || err.status === 403)) denied = err.status;
    else throw err;
  }

  const atmo = factionAtmosphere(overview.guild.faction);
  return (
    <div>
      <PageBanner art={data?.raids[0] ? zoneArt(data.raids[0].instanceKey) : atmo.art} hue={atmo.hue} glow={atmo.glow} title="Raids" subtitle={<>Convocatorias, inscripciones y composición de {overview.guild.name}.</>} aside={data?.viewer.permissions.includes('raids.create') ? <CreateRaidButton region={region} slug={slug} /> : undefined} />
      <div className="mx-auto max-w-5xl px-4 pb-10 sm:px-6">

      {denied ? (
        <div className="mt-8 max-w-2xl">
          <EmptyState icon={Lock} title="Las raids son privadas de cada hermandad" action={denied === 401 ? { href: `/login?returnTo=${encodeURIComponent(base)}`, label: 'Entrar' } : undefined}>
            {denied === 401 ? (
              <>Entra con tu cuenta. Al verificar tus personajes con Battle.net, BlazonGuild te da acceso según tu rango en {overview.guild.name}.</>
            ) : (
              <>Tu cuenta no tiene personajes verificados en {overview.guild.name}. Vincula tus personajes con Battle.net desde Ajustes, o pide a un oficial que te dé acceso.</>
            )}
          </EmptyState>
          {denied === 401 && (
            <p className="mt-3 flex items-center gap-2 text-sm text-fg-3">
              <LogIn className="h-4 w-4" aria-hidden /> Los datos públicos (roster, armería, rankings) siguen disponibles sin cuenta.
            </p>
          )}
        </div>
      ) : (
        data && (
          <>
            <nav aria-label="Periodo" className="mt-6 flex gap-1 border-b border-line">
              {[
                ['upcoming', 'Próximas'],
                ['past', 'Historial'],
              ].map(([k, label]) => (
                <Link key={k} href={`${base}?scope=${k}`} aria-current={scope === k ? 'page' : undefined} className={cn('relative flex h-11 items-center px-3 text-sm', scope === k ? 'text-fg' : 'text-fg-2 hover:text-fg')}>
                  {label}
                  {scope === k && <span aria-hidden className="absolute inset-x-2 -bottom-px h-0.5 bg-accent" />}
                </Link>
              ))}
            </nav>
            {data.raids.length === 0 ? (
              <EmptyState className="mt-6" title={scope === 'upcoming' ? 'No hay raids programadas' : 'Todavía no hay raids pasadas'}>
                {scope === 'upcoming' && (data.viewer.permissions.includes('raids.create') ? 'Programa la primera: los miembros recibirán un aviso.' : 'Cuando el liderazgo convoque una raid, podrás inscribirte aquí.')}
              </EmptyState>
            ) : (
              <ul className="frame-gold mt-4 divide-y divide-black overflow-hidden rounded-[4px]">
                {data.raids.map((r) => (
                  <RaidRow key={r.id} r={r} base={base} />
                ))}
              </ul>
            )}
            <p className="mt-4 text-xs text-fg-3">Horas en horario peninsular español. Hoy es {fmtDate(new Date().toISOString())}.</p>
          </>
        )
      )}
      </div>
    </div>
  );
}
