import type { Metadata } from 'next';
import type { Page, RosterMemberDTO } from '@blazonguild/types';
import { PageBanner } from '@/components/art/CinematicHero';
import { factionAtmosphere } from '@/components/art/raid-art';
import { GuildCrest } from '@/components/game/GuildCrest';
import { RosterView } from '@/components/roster/RosterView';
import { ProvenanceNote } from '@/components/ui/states';
import { api, getGuildOverview, guildPath } from '@/lib/api';
import { fmtInt } from '@/lib/format';

type Props = { params: Promise<{ region: string; slug: string }>; searchParams: Promise<Record<string, string | string[] | undefined>> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug).catch(() => null);
  return { title: o ? `Roster de ${o.guild.name}` : 'Roster' };
}

const ALLOWED = ['q', 'classIds', 'ranks', 'role', 'minLevel', 'maxLevel', 'activeDays', 'sort', 'dir'] as const;

export default async function RosterPage({ params, searchParams }: Props) {
  const { region, slug } = await params;
  const sp = await searchParams;
  const query = new URLSearchParams();
  for (const k of ALLOWED) {
    const v = sp[k];
    if (typeof v === 'string' && v) query.set(k, v);
  }
  query.set('pageSize', '500');
  const [overview, roster] = await Promise.all([getGuildOverview(region, slug), api<Page<RosterMemberDTO>>(`${guildPath(region, slug)}/roster?${query}`)]);
  const view = sp.view === 'directory' ? 'directory' : 'table';

  const atmo = factionAtmosphere(overview.guild.faction);
  return (
    <div>
      <PageBanner
        art={atmo.art}
        hue={atmo.hue}
        glow={atmo.glow}
        crest={<GuildCrest crest={overview.guild.crest} name={overview.guild.name} size={64} />}
        title={view === 'directory' ? 'Armería de la hermandad' : 'La hermandad'}
        subtitle={
          <>
            {fmtInt(overview.stats.members)} personajes en el roster de {overview.guild.name}
            {overview.guild.platformMembers > 0 && <>, {fmtInt(overview.guild.platformMembers)} con cuenta en BlazonGuild</>}
          </>
        }
        aside={<ProvenanceNote provenance={overview.provenance} />}
      />
      <div className="mx-auto max-w-7xl px-4 pb-10 sm:px-6">
      <RosterView
        key={view}
        region={region}
        slug={slug}
        view={view}
        page={roster}
        ranks={overview.stats.rankDistribution}
        classes={overview.stats.classDistribution}
      />
      </div>
    </div>
  );
}
