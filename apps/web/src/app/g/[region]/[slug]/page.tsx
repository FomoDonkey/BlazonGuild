import type { Metadata } from 'next';
import Link from 'next/link';
import { Award, ArrowUpRight, ChevronsUp, Flag, Gem, Lock, Swords, TrendingUp, UserMinus, UserPlus, Users } from 'lucide-react';
import type { ActivityEventDTO, GuildOverviewDTO } from '@blazonguild/types';
import { CinematicHero, Lineup } from '@/components/art/CinematicHero';
import { FiligreeCorner, RuneDivider } from '@/components/art/Ornaments';
import { factionAtmosphere } from '@/components/art/raid-art';
import { CharacterLink, ClassIcon, FactionMark } from '@/components/game/bits';
import { GuildCrest } from '@/components/game/GuildCrest';
import { Histogram, RankedBars } from '@/components/ui/charts';
import { EmptyState, ProvenanceNote, SectionHeading } from '@/components/ui/states';
import { getGuildOverview } from '@/lib/api';
import { calendarParts, fmt1, fmtDate, fmtDateShort, fmtInt, fmtTime, relativeTime } from '@/lib/format';
import { CLASSES, characterHref, classVar, guildHref, qualityVar, REGION_LABEL } from '@/lib/game';

type Params = { params: Promise<{ region: string; slug: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { region, slug } = await params;
  try {
    const o = await getGuildOverview(region, slug);
    return { title: o.guild.name, description: `${o.guild.name}: roster, armería y raids de la hermandad en World of Warcraft: Forever.` };
  } catch {
    return { title: 'Hermandad' };
  }
}

const EVENT_ICON = {
  GUILD_TRACKED: Flag,
  MEMBER_JOINED: UserPlus,
  MEMBER_LEFT: UserMinus,
  RANK_CHANGED: ChevronsUp,
  LEVEL_UP: TrendingUp,
  ITEM_EQUIPPED: Gem,
  ACHIEVEMENT: Award,
  RAID_SCHEDULED: Swords,
} as const;

function dayLabel(iso: string) {
  const d = new Date(iso);
  const today = new Date();
  const diff = Math.floor((new Date(today.toDateString()).getTime() - new Date(d.toDateString()).getTime()) / 86_400_000);
  if (diff === 0) return 'Hoy';
  if (diff === 1) return 'Ayer';
  return fmtDate(iso);
}

function ActivityTitle({ e }: { e: ActivityEventDTO }) {
  if (!e.character || !e.title.startsWith(e.character.displayName)) return <>{e.title}</>;
  const rest = e.title.slice(e.character.displayName.length);
  const item = e.type === 'ITEM_EQUIPPED' ? (e.detail as { name?: string; quality?: string }) : null;
  if (item?.name && rest.includes(item.name)) {
    const [before, after] = rest.split(item.name);
    return (
      <>
        <CharacterLink region={e.character.region} slug={e.character.slug} name={e.character.displayName} classId={e.character.classId} />
        {before}
        <span className="font-medium" style={{ color: qualityVar(item.quality) }}>
          [{item.name}]
        </span>
        {after}
      </>
    );
  }
  return (
    <>
      <CharacterLink region={e.character.region} slug={e.character.slug} name={e.character.displayName} classId={e.character.classId} />
      {rest}
    </>
  );
}

function ActivityFeed({ events }: { events: ActivityEventDTO[] }) {
  if (!events.length) {
    return (
      <EmptyState title="Todavía no hay actividad registrada">
        BlazonGuild detecta altas, bajas, ascensos, subidas de nivel y equipo nuevo comparando cada sincronización con la anterior. Los logros recientes llegan directamente de Battle.net.
      </EmptyState>
    );
  }
  const groups: { day: string; items: ActivityEventDTO[] }[] = [];
  for (const e of events) {
    const day = dayLabel(e.occurredAt);
    const last = groups[groups.length - 1];
    if (last?.day === day) last.items.push(e);
    else groups.push({ day, items: [e] });
  }
  return (
    <div className="space-y-6">
      {groups.map((g) => (
        <section key={g.day} aria-label={g.day}>
          <h3 className="mb-2 text-sm font-medium text-fg-2">{g.day}</h3>
          <ol className="relative space-y-1 border-l border-line pl-5">
            {g.items.map((e) => {
              const Icon = EVENT_ICON[e.type] ?? Award;
              return (
                <li key={e.id} className="relative py-1.5">
                  <span className="absolute -left-[31px] top-2 grid h-5 w-5 place-items-center rounded-full border border-line bg-canvas">
                    <Icon className="h-3 w-3 text-accent" aria-hidden />
                  </span>
                  <p className="text-sm leading-snug text-fg">
                    <ActivityTitle e={e} />
                  </p>
                  <p className="mt-0.5 flex flex-wrap items-center gap-x-3 text-xs text-fg-3">
                    <time dateTime={e.occurredAt}>{fmtTime(e.occurredAt)}</time>
                    <ProvenanceNote provenance={e.provenance} compact />
                  </p>
                </li>
              );
            })}
          </ol>
        </section>
      ))}
    </div>
  );
}

function Figures({ o }: { o: GuildOverviewDTO }) {
  const s = o.stats;
  const items = [
    { label: 'personajes en el roster', value: fmtInt(s.members) },
    { label: 'activos en los últimos 7 días', value: s.activeLast7d === null ? '—' : fmtInt(s.activeLast7d), note: s.activeLast7d === null ? 'Perfiles aún sincronizándose' : `de ${s.detailedMembers} con perfil público` },
    { label: 'nivel medio', value: fmt1(s.averageLevel), note: `mediana ${s.medianLevel ?? '—'}` },
    { label: 'nivel más alto', value: fmtInt(s.maxLevel), note: s.atLevelCap ? `${s.atLevelCap} en el nivel máximo` : 'Nadie en nivel 60 todavía' },
  ];
  return (
    <dl className="grid grid-cols-2 gap-3 sm:grid-cols-4">
      {items.map((it, i) => (
        <div key={it.label} className="plate relative rounded-[3px] px-4 py-4 text-center sm:px-5">
          <FiligreeCorner id={`fig${i}a`} size={20} className="pointer-events-none absolute left-0.5 top-0.5" />
          <FiligreeCorner id={`fig${i}b`} size={20} className="pointer-events-none absolute bottom-0.5 right-0.5 -scale-100" />
          <dt className="sr-only">{it.label}</dt>
          <dd className="t-figure text-3xl leading-none text-[#f3e2b6] sm:text-[2.1rem]">{it.value}</dd>
          <dd className="mt-1.5 text-xs uppercase tracking-[0.16em] text-[#c8b68c]">{it.label}</dd>
          {it.note && <dd className="mt-0.5 text-xs text-white/45">{it.note}</dd>}
        </div>
      ))}
    </dl>
  );
}

export default async function GuildOverviewPage({ params }: Params) {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug);
  const g = o.guild;
  const base = guildHref(g.region, g.slug);
  const tint = g.crest?.backgroundColor ?? 'rgb(var(--c-elevated))';
  const atmo = factionAtmosphere(g.faction);
  const classBars = o.stats.classDistribution.map((b) => {
    const id = Number(b.key);
    return { key: b.key, label: b.label, value: b.count, color: classVar(id), icon: CLASSES.some((c) => c.id === id) ? <ClassIcon classId={id} size={18} /> : null };
  });
  const levelBars = o.stats.levelDistribution.map((b) => ({ key: b.key, label: b.label, value: b.count, hint: `Nivel ${b.label}` }));
  const syncing = g.syncState === 'RUNNING' || o.stats.detailedMembers < o.stats.members * 0.5;

  return (
    <div>
      {/* Cinematic heraldic hero: official instance art per faction, the guild's real crest and its leaders. */}
      <CinematicHero art={atmo.art} hue={atmo.hue} glow={atmo.glow} className="border-b border-black">
        <div aria-hidden className="absolute inset-0 -z-20" style={{ background: `radial-gradient(70% 60% at 50% 10%, color-mix(in srgb, ${tint} 30%, transparent), transparent 70%)` }} />
        <div className="mx-auto flex max-w-6xl flex-col items-center px-4 pb-8 pt-10 text-center sm:px-6 sm:pt-14">
          <div className="relative">
            <div aria-hidden className="absolute -inset-6 rounded-full" style={{ background: `radial-gradient(circle, ${atmo.glow}, transparent 68%)` }} />
            <GuildCrest crest={g.crest} name={g.name} size={124} sizeClass="h-[96px] w-[96px] sm:h-[124px] sm:w-[124px]" className="relative drop-shadow-[0_14px_30px_rgba(0,0,0,0.9)]" />
          </div>
          <h1 className="mt-5 max-w-full break-words">
            <span className="t-display text-gold inline-block text-[2.8rem] leading-[1.05] tracking-[0.05em] sm:text-7xl">{g.name}</span>
          </h1>
          <ul className="mt-3 flex flex-wrap items-center justify-center gap-x-5 gap-y-1 text-sm text-white/75">
            <li>
              <FactionMark faction={g.faction} />
            </li>
            {g.ruleset && <li>Reglas {g.ruleset.name}</li>}
            <li>{REGION_LABEL[g.region] ?? g.region.toUpperCase()}</li>
            {g.foundedAt && <li>Fundada el {fmtDate(g.foundedAt)}</li>}
          </ul>
          <RuneDivider id="hero-rule" className="mt-4 max-w-sm" />

          {o.lineup.length > 0 && <Lineup members={o.lineup} className="mt-2 h-[300px] w-full max-w-4xl sm:h-[380px]" />}

          <div className="mt-6 w-full max-w-4xl">
            <Figures o={o} />
          </div>

          <div className="mt-6 flex w-full max-w-4xl flex-wrap items-center justify-center gap-3">
            <Link href={`${base}/roster`} className="btn-primary">
              <Users className="h-4 w-4" aria-hidden /> Ver la hermandad
            </Link>
            <Link href={`${base}/raids`} className="btn-secondary">
              <Swords className="h-4 w-4" aria-hidden /> Raids
            </Link>
            <Link href={`${base}/rankings`} className="btn-ghost hidden sm:inline-flex">
              Rankings
            </Link>
          </div>
          <p className="mt-4 flex flex-wrap items-center justify-center gap-x-3 gap-y-1 text-xs text-white/50">
            <ProvenanceNote provenance={o.provenance} />
            {syncing && <span className="text-warning">Sincronizando perfiles ({o.stats.detailedMembers}/{o.stats.members})</span>}
          </p>
        </div>
      </CinematicHero>

      <div className="mx-auto grid max-w-6xl gap-x-12 gap-y-12 px-4 py-10 sm:px-6 lg:grid-cols-[minmax(0,1fr)_340px]">
        <div className="min-w-0 space-y-12">
          {o.highlights.length > 0 && (
            <section aria-labelledby="highlights">
              <SectionHeading id="highlights" title="Destacados">
                Valores actuales según Battle.net
              </SectionHeading>
              <ul className="mt-4 grid gap-3 sm:grid-cols-2">
                {o.highlights.map((h) => (
                  <li key={h.metric} className="plate flex items-center gap-4 rounded-[3px] p-4" style={{ ['--cls' as string]: classVar(h.member.classId) }}>
                    {h.member.avatarUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={h.member.avatarUrl} alt="" width={56} height={56} loading="lazy" className="h-14 w-14 rounded-full object-cover ring-2 ring-[color:var(--cls)] ring-offset-2 ring-offset-[rgb(var(--c-sunken))] shadow-[0_0_18px_-4px_var(--cls)]" />
                    ) : (
                      <ClassIcon classId={h.member.classId} size={52} />
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="text-xs text-fg-3">{h.label}</p>
                      <Link href={characterHref(h.member.region, h.member.slug)} className="block truncate font-semibold hover:underline" style={{ color: classVar(h.member.classId) }}>
                        {h.member.displayName}
                      </Link>
                    </div>
                    <p className="t-figure text-2xl text-fg">
                      {fmtInt(h.value)}
                      <span className="ml-1 font-sans text-xs text-fg-3">{h.unit}</span>
                    </p>
                  </li>
                ))}
              </ul>
            </section>
          )}

          <section aria-labelledby="activity">
            <SectionHeading id="activity" title="Actividad reciente">
              <Link href={`${base}/roster`} className="link inline-flex items-center gap-1">
                Roster completo <ArrowUpRight className="h-3.5 w-3.5" aria-hidden />
              </Link>
            </SectionHeading>
            <div className="mt-5">
              <ActivityFeed events={o.recentActivity} />
            </div>
          </section>
        </div>

        <aside className="space-y-10">
          <section aria-labelledby="raids">
            <SectionHeading id="raids" title="Próximas raids" />
            <div className="mt-4">
              {o.upcomingRaids === null ? (
                <EmptyState icon={Lock} title="Solo para miembros">
                  Las convocatorias son privadas de cada hermandad. Entra con Battle.net para verificar tus personajes y ver las raids de {g.name}.
                </EmptyState>
              ) : o.upcomingRaids.length === 0 ? (
                <EmptyState title="No hay raids programadas" action={o.viewer.permissions.includes('raids.create') ? { href: `${base}/raids`, label: 'Programar una raid' } : undefined}>
                  {o.viewer.permissions.includes('raids.create') ? 'Crea la primera convocatoria y avisaremos a los miembros.' : 'Cuando el liderazgo convoque una, aparecerá aquí.'}
                </EmptyState>
              ) : (
                <ul className="divide-y divide-line rounded-md border border-line bg-surface">
                  {o.upcomingRaids.map((r) => {
                    const c = calendarParts(r.startsAt);
                    return (
                      <li key={r.id}>
                        <Link href={`${base}/raids/${r.id}`} className="flex items-center gap-4 p-3 hover:bg-elevated/50">
                          <span className="grid w-12 shrink-0 text-center leading-none">
                            <span className="text-2xs uppercase text-fg-3">{c.weekday}</span>
                            <span className="t-figure text-2xl">{c.day}</span>
                            <span className="text-2xs text-fg-3">{c.month}</span>
                          </span>
                          <span className="min-w-0">
                            <span className="block truncate font-medium">{r.title}</span>
                            <span className="t-num block text-xs text-fg-2">
                              {fmtTime(r.startsAt)}, {r.counts.confirmed}/{r.capacity} confirmados
                            </span>
                          </span>
                        </Link>
                      </li>
                    );
                  })}
                </ul>
              )}
            </div>
          </section>

          <section aria-labelledby="composition">
            <SectionHeading id="composition" title="Composición">
              {fmtInt(o.stats.members)} personajes
            </SectionHeading>
            <div className="mt-4">
              <RankedBars data={classBars} total={o.stats.members} caption="Personajes por clase" />
            </div>
          </section>

          <section aria-labelledby="levels">
            <SectionHeading id="levels" title="Niveles" />
            <p className="mt-1 text-xs text-fg-3">Personajes por tramo de nivel</p>
            <div className="mt-5">
              <Histogram data={levelBars} caption="Personajes por tramo de nivel" unitLabel="personajes" />
            </div>
          </section>

          <section aria-labelledby="pve">
            <SectionHeading id="pve" title="Progreso de banda" />
            <div className="mt-4">
              <EmptyState title="Sin encuentros registrados">
                Battle.net no publica todavía encuentros de banda para esta hermandad. El progreso se mostrará en cuanto haya muertes de jefes registradas (API o registros de combate).
              </EmptyState>
            </div>
          </section>

          <p className="text-xs text-fg-3">
            Última sincronización {relativeTime(g.lastSyncedAt)} ({fmtDateShort(g.lastSyncedAt)}). Los datos de juego proceden de la API oficial de Battle.net.
          </p>
        </aside>
      </div>
    </div>
  );
}
