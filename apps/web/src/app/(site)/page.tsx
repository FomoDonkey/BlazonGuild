import Link from 'next/link';
import type { GuildSummaryDTO } from '@blazonguild/types';
import { CinematicHero } from '@/components/art/CinematicHero';
import { RuneDivider } from '@/components/art/Ornaments';
import { zoneArt } from '@/components/art/raid-art';
import { FactionMark } from '@/components/game/bits';
import { GuildCrest } from '@/components/game/GuildCrest';
import { ExploreSearch } from '@/components/shell/ExploreSearch';
import { EmptyState, ErrorPanel } from '@/components/ui/states';
import { api, ApiFailure, getMe } from '@/lib/api';
import { fmtInt, relativeTime } from '@/lib/format';
import { characterHref, classVar, guildHref } from '@/lib/game';

export default async function ExplorePage() {
  const me = await getMe();
  let guilds: GuildSummaryDTO[] = [];
  let failure: string | null = null;
  try {
    guilds = await api<GuildSummaryDTO[]>('/v1/guilds?limit=12');
  } catch (err) {
    failure = err instanceof ApiFailure ? err.message : 'Error inesperado';
  }

  return (
    <div>
      <CinematicHero art={zoneArt('BWL')} hue={22} glow="rgba(255,120,60,.22)" className="border-b border-black" artOpacity={0.6}>
        <div className="mx-auto max-w-3xl px-4 pb-16 pt-16 text-center sm:px-6 sm:pt-24">
          <h1>
            <span className="t-display text-gold inline-block text-5xl leading-tight sm:text-7xl">Tu hermandad, de un vistazo</span>
          </h1>
          <RuneDivider id="explore-rule" className="mx-auto mt-4 max-w-sm" />
          <p className="mx-auto mt-4 max-w-xl text-base text-white/75">
            Roster, armería, raids y clasificaciones de cualquier hermandad de World of Warcraft: Forever, con datos oficiales de Battle.net. Escribe su nombre para empezar.
          </p>
          <div className="plate mx-auto mt-8 max-w-xl rounded-[4px] p-3 text-left">
            <ExploreSearch />
          </div>
        </div>
      </CinematicHero>

      <div className="mx-auto max-w-6xl space-y-12 px-4 py-10 sm:px-6">
        {me && me.memberships.length > 0 && (
          <section aria-labelledby="mine">
            <h2 id="mine" className="t-display text-xl">
              {me.memberships.length === 1 ? 'Tu hermandad' : 'Hermandades de tus personajes'}
            </h2>
            <ul className="mt-4 flex flex-wrap gap-3">
              {me.memberships.map((m) => {
                const chars = me.characters.filter((c) => c.guildSlug === m.guild.slug);
                return (
                  <li key={m.guild.id}>
                    <Link href={guildHref(m.guild.region, m.guild.slug)} className="plate flex items-center gap-3 rounded-[4px] py-2.5 pl-2.5 pr-5 transition-colors hover:border-accent/40">
                      <GuildCrest crest={m.guild.crest} name={m.guild.name} size={44} />
                      <span>
                        <span className="t-display block text-lg leading-tight">{m.guild.name}</span>
                        {chars.length > 0 && (
                          <span className="block text-xs text-fg-3">
                            con{' '}
                            {chars.map((c, i) => (
                              <span key={c.id} style={{ color: classVar(c.classId) }}>
                                {i > 0 ? ', ' : ''}
                                {c.displayName}
                              </span>
                            ))}
                          </span>
                        )}
                      </span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          </section>
        )}

        {me && me.characters.length > 0 && (
          <section aria-labelledby="chars">
            <h2 id="chars" className="t-display text-xl">
              Tus personajes
            </h2>
            <ul className="mt-4 flex flex-wrap gap-x-6 gap-y-2">
              {me.characters.map((c) => (
                <li key={c.id}>
                  <Link href={characterHref(c.region, c.slug)} className="font-semibold hover:underline" style={{ color: classVar(c.classId) }}>
                    {c.displayName}
                  </Link>
                  <span className="t-num ml-2 text-sm text-fg-3">nivel {c.level}</span>
                </li>
              ))}
            </ul>
          </section>
        )}

        <section aria-labelledby="tracked">
          <div className="flex items-end justify-between gap-4">
            <h2 id="tracked" className="t-display text-xl">
              Hermandades en BlazonGuild
            </h2>
            <p className="text-sm text-fg-3">Ordenadas por actividad reciente</p>
          </div>
          {failure ? (
            <div className="mt-4">
              <ErrorPanel title="No hemos podido cargar las hermandades" message={failure} />
            </div>
          ) : guilds.length === 0 ? (
            <EmptyState className="mt-4" title="Aún no se ha consultado ninguna hermandad">
              Busca la tuya arriba: se importará automáticamente desde Battle.net la primera vez.
            </EmptyState>
          ) : (
            <ul className="mt-3 grid gap-x-10 border-t border-line lg:grid-cols-2">
              {guilds.map((g) => (
                <li key={g.id} className="border-b border-line">
                  <Link href={guildHref(g.region, g.slug)} className="group flex h-full items-center gap-4 px-1 py-4 hover:bg-elevated/30">
                    <GuildCrest crest={g.crest} name={g.name} size={56} className="transition-transform duration-300 group-hover:scale-105" />
                    <span className="min-w-0">
                      <span className="t-display block truncate text-lg leading-tight group-hover:text-accent">{g.name}</span>
                      <span className="mt-0.5 flex flex-wrap items-center gap-x-3 text-sm text-fg-2">
                        <FactionMark faction={g.faction} className="text-sm" />
                        <span className="t-num">{fmtInt(g.memberCount)} personajes</span>
                      </span>
                      <span className="text-xs text-fg-3">Actualizada {relativeTime(g.lastSyncedAt)}</span>
                    </span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
}
