import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Award, Flag, Hammer, History } from 'lucide-react';
import { isRegion, type CharacterStatsDTO, type StatRowDTO } from '@blazonguild/types';
import { Paperdoll } from '@/components/armory/Paperdoll';
import { SyncCharacterButton } from '@/components/armory/SyncCharacterButton';
import { TalentTrees } from '@/components/armory/TalentTrees';
import { CinematicHero } from '@/components/art/CinematicHero';
import { FiligreeCorner } from '@/components/art/Ornaments';
import { factionAtmosphere } from '@/components/art/raid-art';
import { FactionMark } from '@/components/game/bits';
import { EmptyState, ErrorPanel, Meter, ProvenanceNote, SectionHeading } from '@/components/ui/states';
import { ApiFailure, getArmory, getMe } from '@/lib/api';
import { fmt1, fmt2, fmtDate, fmtDateShort, fmtInt, relativeTime } from '@/lib/format';
import { classById, classVar, guildHref, raceById, specById } from '@/lib/game';

type Props = { params: Promise<{ region: string; slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  try {
    const a = await getArmory(region, slug);
    const cls = classById(a.character.classId);
    return { title: a.character.displayName, description: `${a.character.displayName}, ${cls?.nameEs ?? ''} de nivel ${a.character.level} en World of Warcraft: Forever.` };
  } catch {
    return { title: 'Armería' };
  }
}

function statValue(r: StatRowDTO) {
  if (r.hint === 'range') return `${fmtInt(r.value)} – ${fmtInt(r.base)}`;
  switch (r.format) {
    case 'pct':
      return `${fmt2(r.value)} %`;
    case 'float1':
      return fmt1(r.value);
    case 'speed':
      return fmt2(r.value);
    default:
      return fmtInt(r.value);
  }
}

function StatsPanel({ stats }: { stats: CharacterStatsDTO }) {
  return (
    <div className="gap-10 md:columns-2 xl:columns-4 [&>*]:mb-7 [&>*]:break-inside-avoid">
      <div className="space-y-3">
        {stats.health !== null && (
          <div>
            <div className="flex justify-between text-sm">
              <span className="text-fg-2">Salud</span>
              <span className="t-num font-semibold">{fmtInt(stats.health)}</span>
            </div>
            <Meter value={1} max={1} className="mt-1 h-2" color="#3fbf5a" />
          </div>
        )}
        {stats.power !== null && (
          <div>
            <div className="flex justify-between text-sm">
              <span className="text-fg-2">{stats.powerType ?? 'Poder'}</span>
              <span className="t-num font-semibold">{fmtInt(stats.power)}</span>
            </div>
            <Meter value={1} max={1} className="mt-1 h-2" color={stats.powerType === 'Ira' ? '#d0423a' : stats.powerType === 'Energía' ? '#e6cf3a' : '#3d7bdc'} />
          </div>
        )}
      </div>
      <dl className="plate divide-y divide-white/5 rounded-[3px]">
        {stats.attributes.map((r) => {
          const bonus = r.base !== undefined ? r.value - r.base : 0;
          return (
            <div key={r.key} className="flex items-baseline justify-between px-3 py-2 text-sm">
              <dt className="text-fg-2">{r.label}</dt>
              <dd className="t-num font-semibold">
                {fmtInt(r.value)}
                {bonus > 0 && <span className="ml-1.5 text-xs font-normal text-success">(+{bonus})</span>}
              </dd>
            </div>
          );
        })}
      </dl>
      {stats.sections.map((s) => (
        <section key={s.key} aria-label={s.label}>
          <h3 className="mb-1.5 text-sm font-medium text-fg">{s.label}</h3>
          <dl className="space-y-1">
            {s.rows.map((r) => (
              <div key={r.key} className="flex items-baseline justify-between gap-3 text-sm">
                <dt className="text-fg-2">{r.label}</dt>
                <dd className="t-num text-fg">{statValue(r)}</dd>
              </div>
            ))}
          </dl>
        </section>
      ))}
      <p className="max-w-xs text-xs text-fg-3">Solo se muestran atributos que existen en WoW: Forever. Battle.net devuelve también campos de expansiones modernas (maestría, versatilidad…) que aquí se omiten.</p>
    </div>
  );
}

export default async function ArmoryCharacterPage({ params }: Props) {
  const { region, slug } = await params;
  if (!isRegion(region)) notFound();
  let a;
  try {
    a = await getArmory(region, slug);
  } catch (err) {
    if (err instanceof ApiFailure && err.status === 404) notFound();
    return (
      <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6">
        <ErrorPanel title="No hemos podido cargar este personaje" message={err instanceof ApiFailure ? err.message : 'Error inesperado.'} />
      </div>
    );
  }
  const me = await getMe();
  const c = a.character;
  const cls = classById(c.classId);
  const race = raceById(c.raceId);
  const dominant = a.talents?.trees.reduce((best, t) => (t.spentPoints > best.spentPoints ? t : best), a.talents.trees[0]);
  const spec = dominant && dominant.spentPoints > 0 ? specById(dominant.specId) : null;
  const latest = a.history[a.history.length - 1];
  const first = a.history[0];

  const atmo = factionAtmosphere(c.faction);
  return (
    <div>
      <CinematicHero art={atmo.art} hue={atmo.hue} glow={`color-mix(in srgb, ${classVar(c.classId)} 22%, transparent)`} embers={45} artOpacity={0.42} className="border-b border-black">
      <div className="mx-auto max-w-[1400px] px-4 pb-10 pt-8 sm:px-6">
      <header className="flex flex-col gap-4 pb-6 lg:flex-row lg:items-end lg:justify-between">
        <div className="flex items-center gap-4">
          {a.media.avatarUrl && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={a.media.avatarUrl} alt="" width={76} height={76} className="h-16 w-16 rounded-full object-cover ring-2 ring-offset-2 ring-offset-black sm:h-[76px] sm:w-[76px]" style={{ ['--tw-ring-color' as string]: classVar(c.classId), boxShadow: `0 0 26px -4px ${classVar(c.classId)}` }} />
          )}
          <div className="min-w-0">
            <h1 className="t-display break-words text-4xl leading-none sm:text-6xl" style={{ color: classVar(c.classId), textShadow: `0 2px 0 #000, 0 0 28px color-mix(in srgb, ${classVar(c.classId)} 45%, transparent)` }}>
              {c.displayName}
            </h1>
            <p className="mt-2 text-white/75">
              <span className="t-num font-semibold text-fg">Nivel {c.level}</span> {race?.nameEs ?? ''} {cls?.nameEs ?? ''}
              {spec && <span className="text-fg-3"> ({spec.nameEs})</span>}
            </p>
            <p className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
              <FactionMark faction={c.faction} />
              {c.guild && (
                <Link href={guildHref(c.guild.region, c.guild.slug)} className="link">
                  {c.guild.name}
                  {c.guild.rankIndex !== null && <span className="text-fg-3"> (rango {c.guild.rankIndex})</span>}
                </Link>
              )}
              {c.ruleset && <span className="text-fg-2">Reglas {c.ruleset.name}</span>}
              <span className="text-fg-3">Última conexión {relativeTime(c.lastLoginAt)}</span>
            </p>
          </div>
        </div>
        <div className="flex flex-wrap items-end gap-6">
          <div className="plate relative rounded-[3px] px-5 py-3 text-center">
            <FiligreeCorner id="ilvl-a" size={18} className="pointer-events-none absolute left-0.5 top-0.5" />
            <FiligreeCorner id="ilvl-b" size={18} className="pointer-events-none absolute bottom-0.5 right-0.5 -scale-100" />
            <p className="t-figure text-4xl leading-none text-[#f3e2b6]">{c.equippedItemLevel ?? '—'}</p>
            <p className="mt-1 text-[11px] uppercase tracking-[0.16em] text-[#c8b68c]">nivel de objeto</p>
          </div>
          <div className="space-y-2">
            <ProvenanceNote provenance={a.provenance} />
            {me && <SyncCharacterButton region={c.region} slug={c.slug} />}
          </div>
        </div>
      </header>

        <section aria-labelledby="gear" className="mx-auto max-w-5xl">
          <h2 id="gear" className="sr-only">
            Equipo
          </h2>
          {a.equipment.length ? (
            <Paperdoll equipment={a.equipment} renderUrl={a.media.renderUrl} classId={c.classId} name={c.displayName} />
          ) : (
            <EmptyState title="Equipo no disponible">Battle.net no ha devuelto el equipo de este personaje (puede ser un perfil privado).</EmptyState>
          )}
        </section>
      </div>
      </CinematicHero>

      <div className="mx-auto max-w-[1400px] space-y-12 px-4 py-10 sm:px-6">
        <section aria-labelledby="stats">
          <SectionHeading id="stats" title="Atributos" />
          <div className="mt-5">{a.stats ? <StatsPanel stats={a.stats} /> : <EmptyState title="Estadísticas no disponibles" />}</div>
        </section>

      <section aria-labelledby="talents">
        <SectionHeading id="talents" title="Talentos">
          {a.talents ? (
            <span className="t-num">
              {a.talents.trees.map((t) => t.spentPoints).join(' / ')} ({a.talents.totalPoints} puntos)
            </span>
          ) : null}
        </SectionHeading>
        <div className="mt-5">{a.talents ? <TalentTrees loadout={a.talents} /> : <EmptyState title="Talentos no disponibles" />}</div>
      </section>

      <div className="grid gap-10 md:grid-cols-2 xl:grid-cols-4">
        <section aria-labelledby="professions">
          <SectionHeading id="professions" title="Profesiones" />
          <div className="mt-4">
            {a.professions.length ? (
              <ul className="space-y-3">
                {a.professions.map((p) => (
                  <li key={p.id}>
                    <div className="flex items-baseline justify-between text-sm">
                      <span className="flex items-center gap-2">
                        <Hammer className="h-3.5 w-3.5 text-fg-3" aria-hidden />
                        {p.name}
                        {p.kind === 'secondary' && <span className="text-xs text-fg-3">secundaria</span>}
                      </span>
                      <span className="t-num text-fg-2">
                        {p.skill}/{p.max}
                      </span>
                    </div>
                    <Meter value={p.skill} max={p.max || 300} className="mt-1.5" />
                  </li>
                ))}
              </ul>
            ) : (
              <EmptyState title="Sin profesiones" />
            )}
          </div>
        </section>

        <section aria-labelledby="pvp">
          <SectionHeading id="pvp" title="JcJ" />
          <div className="mt-4">
            {a.pvp ? (
              <dl className="space-y-3">
                <div>
                  <dt className="text-sm text-fg-2">Muertes con honor</dt>
                  <dd className="t-figure text-3xl">{fmtInt(a.pvp.honorableKills)}</dd>
                </div>
                <div>
                  <dt className="text-sm text-fg-2">Rango de honor</dt>
                  <dd className="t-num text-lg">{a.pvp.rank > 0 ? a.pvp.rank : 'Sin rango'}</dd>
                </div>
              </dl>
            ) : (
              <EmptyState icon={Flag} title="Sin datos JcJ" />
            )}
          </div>
        </section>

        <section aria-labelledby="ach">
          <SectionHeading id="ach" title="Logros recientes" />
          <div className="mt-4">
            {a.recentAchievements.length ? (
              <ul className="space-y-2.5">
                {a.recentAchievements.map((x) => (
                  <li key={x.id} className="flex gap-2.5 text-sm">
                    <Award className="mt-0.5 h-4 w-4 shrink-0 text-accent" aria-hidden />
                    <span>
                      {x.name}
                      <span className="block text-xs text-fg-3">{fmtDate(x.completedAt)}</span>
                    </span>
                  </li>
                ))}
              </ul>
            ) : (
              <EmptyState icon={Award} title="Sin logros recientes" />
            )}
          </div>
        </section>

        <section aria-labelledby="history">
          <SectionHeading id="history" title="Historial" />
          <div className="mt-4 space-y-3 text-sm">
            {first && latest ? (
              <>
                <p className="flex items-start gap-2.5">
                  <History className="mt-0.5 h-4 w-4 shrink-0 text-fg-3" aria-hidden />
                  <span>
                    {a.history.length === 1 ? 'Primera captura' : `${a.history.length} capturas`} desde el {fmtDateShort(first.takenAt)}.
                    {a.history.length > 1 && latest.level > first.level && (
                      <span className="block text-fg-2">
                        Ha subido del nivel {first.level} al {latest.level}.
                      </span>
                    )}
                  </span>
                </p>
                <p className="text-xs text-fg-3">BlazonGuild guarda una captura nueva cada vez que cambia el perfil en Battle.net. Con el tiempo verás aquí la evolución del nivel, el equipo y los talentos.</p>
              </>
            ) : (
              <EmptyState title="Sin historial" />
            )}
          </div>
        </section>
      </div>
      </div>
    </div>
  );
}
