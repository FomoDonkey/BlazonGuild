import type { Metadata } from 'next';
import Link from 'next/link';
import { Lock } from 'lucide-react';
import { DUNGEONS, type Page, type RosterMemberDTO, type ViewerContextDTO } from '@blazonguild/types';
import { PageBanner } from '@/components/art/CinematicHero';
import { zoneArt } from '@/components/art/raid-art';
import { GroupFinder, type GroupDTO } from '@/components/dungeons/GroupFinder';
import { GuildCrest } from '@/components/game/GuildCrest';
import { EmptyState, SectionHeading } from '@/components/ui/states';
import { api, ApiFailure, getGuildOverview, getMe, guildPath } from '@/lib/api';
import { fmtInt } from '@/lib/format';
import { guildHref } from '@/lib/game';

type Props = { params: Promise<{ region: string; slug: string }>; searchParams: Promise<{ d?: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug).catch(() => null);
  return { title: o ? `Mazmorras de ${o.guild.name}` : 'Mazmorras' };
}

export default async function DungeonsPage({ params, searchParams }: Props) {
  const { region, slug } = await params;
  const { d } = await searchParams;
  const base = guildPath(region, slug);
  const [o, roster, me] = await Promise.all([getGuildOverview(region, slug), api<Page<RosterMemberDTO>>(`${base}/roster?pageSize=500`), getMe()]);
  let finder: { viewer: ViewerContextDTO; groups: GroupDTO[] } | null = null;
  let denied = false;
  try {
    finder = await api(`${base}/groups`);
  } catch (err) {
    if (err instanceof ApiFailure && (err.status === 401 || err.status === 403)) denied = true;
    else throw err;
  }
  const guildSlug = decodeURIComponent(slug).toLowerCase();
  const myChars = (me?.characters ?? []).filter((c) => c.guildSlug === guildSlug).map((c) => ({ id: c.id, displayName: c.displayName, classId: c.classId, level: c.level }));
  const inRange = (min: number, max: number) => roster.items.filter((m) => m.level >= min && m.level <= max).length;
  const preset = DUNGEONS.some((x) => x.key === d) ? d : undefined;

  return (
    <div>
      <PageBanner art={zoneArt('BRD')} hue={22} glow="rgba(255,120,60,.24)" crest={<GuildCrest crest={o.guild.crest} name={o.guild.name} size={64} />} title="Mazmorras" subtitle={<>Forma grupo con tu hermandad y descubre a dónde podéis ir juntos</>} />

      <div className="mx-auto max-w-6xl space-y-12 px-4 py-10 sm:px-6">
        <section aria-labelledby="finder" id="buscador">
          <SectionHeading id="finder" title="Buscador de grupo" />
          <div className="mt-4">
            {denied ? (
              <EmptyState icon={Lock} title="El buscador es para miembros de la hermandad" action={{ href: `/login?returnTo=${encodeURIComponent(guildHref(region, slug, '/dungeons'))}`, label: 'Entrar' }}>
                Entra con Battle.net para formar grupos con {o.guild.name}.
              </EmptyState>
            ) : (
              finder && <GroupFinder region={region} slug={slug} groups={finder.groups} myChars={myChars} canCreate={finder.viewer.permissions.includes('raids.signup')} preset={preset} />
            )}
          </div>
        </section>

        <section aria-labelledby="directory">
          <SectionHeading id="directory" title="Directorio">
            Niveles de referencia del juego clásico
          </SectionHeading>
          <ul className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {DUNGEONS.map((x) => {
              const count = inRange(x.min, x.max);
              return (
                <li key={x.key}>
                  <article className="cinematic frame-gold group relative isolate flex h-44 flex-col justify-end overflow-hidden rounded-[4px] p-4">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={zoneArt(x.key)} alt="" aria-hidden loading="lazy" className="absolute inset-0 -z-20 h-full w-full object-cover opacity-75 transition-transform duration-700 group-hover:scale-105" />
                    <span aria-hidden className="absolute inset-0 -z-10 bg-gradient-to-t from-[#07090d] via-[#07090d]/65 to-transparent" />
                    <h3 className="t-display text-lg leading-tight text-white [text-shadow:0_2px_6px_#000]">{x.nameEs}</h3>
                    <p className="text-xs text-white/65">
                      {x.zoneEs}, niveles <span className="t-num">{x.min}–{x.max}</span>
                      {x.size > 5 ? `, ${x.size} jugadores` : ''}
                    </p>
                    {x.faction && o.guild.faction && x.faction !== o.guild.faction && (
                      <p className="text-xs text-warning">En territorio de la {x.faction === 'HORDE' ? 'Horda' : 'Alianza'}</p>
                    )}
                    <div className="mt-2 flex items-center justify-between gap-2">
                      <span className={count >= 5 ? 'text-xs text-success' : 'text-xs text-white/55'}>{fmtInt(count)} de la hermandad en nivel</span>
                      {!denied && (
                        <Link href={`${guildHref(region, slug, '/dungeons')}?d=${x.key}#buscador`} className="rounded px-2 py-1 text-xs text-accent ring-1 ring-accent/40 hover:bg-accent/10">
                          Formar grupo
                        </Link>
                      )}
                    </div>
                  </article>
                </li>
              );
            })}
          </ul>
        </section>
      </div>
    </div>
  );
}
