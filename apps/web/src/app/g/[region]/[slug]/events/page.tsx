import type { Metadata } from 'next';
import Link from 'next/link';
import { ChevronLeft, ChevronRight, Lock } from 'lucide-react';
import type { RaidSummaryDTO, ViewerContextDTO } from '@blazonguild/types';
import { PageBanner } from '@/components/art/CinematicHero';
import { factionAtmosphere, zoneArt } from '@/components/art/raid-art';
import { GuildCrest } from '@/components/game/GuildCrest';
import { CreateRaidButton } from '@/components/raids/CreateRaid';
import { EmptyState } from '@/components/ui/states';
import { api, ApiFailure, getGuildOverview, guildPath } from '@/lib/api';
import { fmtDateTime, fmtTime } from '@/lib/format';
import { guildHref } from '@/lib/game';
import { cn } from '@/lib/utils';

type Props = { params: Promise<{ region: string; slug: string }>; searchParams: Promise<{ m?: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug).catch(() => null);
  return { title: o ? `Calendario de ${o.guild.name}` : 'Eventos' };
}

const TZ = 'Europe/Madrid';
const dayKey = (d: Date) => new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
const monthLabel = new Intl.DateTimeFormat('es-ES', { month: 'long', year: 'numeric', timeZone: 'UTC' });
const WEEKDAYS = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

export default async function EventsPage({ params, searchParams }: Props) {
  const { region, slug } = await params;
  const { m } = await searchParams;
  const o = await getGuildOverview(region, slug);
  const atmo = factionAtmosphere(o.guild.faction);
  const today = dayKey(new Date());
  const [ty, tm] = (m && /^\d{4}-\d{2}$/.test(m) ? m : today.slice(0, 7)).split('-').map(Number);
  const first = new Date(Date.UTC(ty, tm - 1, 1));
  const prev = new Date(Date.UTC(ty, tm - 2, 1)).toISOString().slice(0, 7);
  const next = new Date(Date.UTC(ty, tm, 1)).toISOString().slice(0, 7);
  const lead = (first.getUTCDay() + 6) % 7; // Monday-first grid
  const daysInMonth = new Date(Date.UTC(ty, tm, 0)).getUTCDate();
  const cells = Array.from({ length: Math.ceil((lead + daysInMonth) / 7) * 7 }, (_, i) => {
    const d = new Date(Date.UTC(ty, tm - 1, i - lead + 1));
    return { key: d.toISOString().slice(0, 10), day: d.getUTCDate(), inMonth: d.getUTCMonth() === tm - 1 };
  });
  const base = guildHref(region, slug);

  let data: { viewer: ViewerContextDTO; raids: RaidSummaryDTO[] } | null = null;
  let denied = false;
  try {
    data = await api(`${guildPath(region, slug)}/raids?scope=all`);
  } catch (err) {
    if (err instanceof ApiFailure && (err.status === 401 || err.status === 403)) denied = true;
    else throw err;
  }
  const byDay = new Map<string, RaidSummaryDTO[]>();
  for (const r of data?.raids ?? []) {
    const k = dayKey(new Date(r.startsAt));
    byDay.set(k, [...(byDay.get(k) ?? []), r]);
  }
  const monthRaids = (data?.raids ?? []).filter((r) => dayKey(new Date(r.startsAt)).startsWith(`${ty}-${String(tm).padStart(2, '0')}`)).sort((a, b) => a.startsAt.localeCompare(b.startsAt));

  return (
    <div>
      <PageBanner art={atmo.art} hue={atmo.hue} glow={atmo.glow} crest={<GuildCrest crest={o.guild.crest} name={o.guild.name} size={64} />} title="Calendario" subtitle={<>Raids y actividades de {o.guild.name} (hora peninsular)</>} aside={data?.viewer.permissions.includes('raids.create') ? <CreateRaidButton region={region} slug={slug} /> : undefined} />
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6">
        {denied ? (
          <EmptyState icon={Lock} title="El calendario es privado de cada hermandad" action={{ href: `/login?returnTo=${encodeURIComponent(`${base}/events`)}`, label: 'Entrar' }}>
            Entra con Battle.net para ver las convocatorias de {o.guild.name}.
          </EmptyState>
        ) : (
          <>
            <div className="mb-4 flex items-center justify-between">
              <Link href={`${base}/events?m=${prev}`} className="btn-ghost h-10 min-h-0 px-3" aria-label="Mes anterior">
                <ChevronLeft className="h-4 w-4" aria-hidden />
              </Link>
              <h2 className="t-display text-2xl">{monthLabel.format(first).replace(/^./, (ch) => ch.toUpperCase())}</h2>
              <Link href={`${base}/events?m=${next}`} className="btn-ghost h-10 min-h-0 px-3" aria-label="Mes siguiente">
                <ChevronRight className="h-4 w-4" aria-hidden />
              </Link>
            </div>

            {/* Desktop/tablet: month grid */}
            <div className="frame-gold hidden overflow-hidden rounded-[4px] md:block">
              <div className="surface-metal grid grid-cols-7 text-center text-xs uppercase tracking-[0.14em] text-fg-2">
                {WEEKDAYS.map((w) => (
                  <div key={w} className="py-2">
                    {w}
                  </div>
                ))}
              </div>
              <div className="grid grid-cols-7">
                {cells.map((c) => {
                  const items = byDay.get(c.key) ?? [];
                  return (
                    <div key={c.key} className={cn('min-h-[112px] border-t border-l border-line/60 p-1.5 first:border-l-0 [&:nth-child(7n+1)]:border-l-0', !c.inMonth && 'bg-black/20 text-fg-3')}>
                      <p className={cn('t-num mb-1 inline-grid h-6 min-w-6 place-items-center rounded-full px-1 text-xs', c.key === today ? 'bg-accent font-semibold text-accent-on' : 'text-fg-2')}>{c.day}</p>
                      <ul className="space-y-1">
                        {items.map((r) => (
                          <li key={r.id}>
                            <Link href={`${base}/raids/${r.id}`} className="cinematic group relative isolate block overflow-hidden rounded-sm px-1.5 py-1 text-[11px] leading-tight ring-1 ring-white/10 hover:ring-accent/60" title={`${r.title}, ${fmtTime(r.startsAt)}`}>
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img src={zoneArt(r.instanceKey)} alt="" aria-hidden className="absolute inset-0 -z-10 h-full w-full object-cover opacity-45" />
                              <span className="t-num block text-white/70">{fmtTime(r.startsAt)}</span>
                              <span className={cn('block truncate font-semibold text-white', r.status === 'CANCELLED' && 'line-through opacity-60')}>{r.title}</span>
                            </Link>
                          </li>
                        ))}
                      </ul>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Mobile: comfortable agenda */}
            <div className="md:hidden">
              {monthRaids.length === 0 ? (
                <EmptyState title="Nada programado este mes" />
              ) : (
                <ol className="space-y-3">
                  {monthRaids.map((r) => (
                    <li key={r.id}>
                      <Link href={`${base}/raids/${r.id}`} className="cinematic frame-gold relative isolate block overflow-hidden rounded-[4px] p-4">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img src={zoneArt(r.instanceKey)} alt="" aria-hidden className="absolute inset-0 -z-20 h-full w-full object-cover opacity-50" />
                        <span aria-hidden className="absolute inset-0 -z-10 bg-gradient-to-r from-[#07090d] via-[#07090d]/80 to-transparent" />
                        <span className="block text-xs capitalize text-white/70">{fmtDateTime(r.startsAt)}</span>
                        <span className="t-display mt-0.5 block text-lg text-white">{r.title}</span>
                        <span className="t-num block text-xs text-white/60">
                          {r.instanceName}, {r.counts.confirmed}/{r.capacity} confirmados
                        </span>
                      </Link>
                    </li>
                  ))}
                </ol>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
