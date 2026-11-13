import type { Metadata } from 'next';
import Link from 'next/link';
import { Swords } from 'lucide-react';
import type { Page, RosterMemberDTO } from '@blazonguild/types';
import { PageBanner } from '@/components/art/CinematicHero';
import { FiligreeCorner } from '@/components/art/Ornaments';
import { factionAtmosphere } from '@/components/art/raid-art';
import { ClassIcon } from '@/components/game/bits';
import { GuildCrest } from '@/components/game/GuildCrest';
import { RankedBars } from '@/components/ui/charts';
import { EmptyState, ProvenanceNote, SectionHeading } from '@/components/ui/states';
import { api, getGuildOverview, guildPath } from '@/lib/api';
import { fmt1, fmtInt } from '@/lib/format';
import { CLASSES, characterHref, classVar } from '@/lib/game';

type Props = { params: Promise<{ region: string; slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug).catch(() => null);
  return { title: o ? `JcJ de ${o.guild.name}` : 'JcJ' };
}

export default async function PvpPage({ params }: Props) {
  const { region, slug } = await params;
  const [o, roster] = await Promise.all([getGuildOverview(region, slug), api<Page<RosterMemberDTO>>(`${guildPath(region, slug)}/roster?sort=honorableKills&dir=desc&pageSize=500`)]);
  const atmo = factionAtmosphere(o.guild.faction);
  const known = roster.items.filter((m) => m.honorableKills !== null);
  const fighters = known.filter((m) => (m.honorableKills ?? 0) > 0);
  const total = fighters.reduce((s, m) => s + (m.honorableKills ?? 0), 0);
  const top = fighters.slice(0, 15);
  const max = Math.max(1, ...top.map((m) => m.honorableKills ?? 0));
  const byClass = CLASSES.map((c) => ({ key: String(c.id), label: c.nameEs, value: fighters.filter((m) => m.classId === c.id).reduce((s, m) => s + (m.honorableKills ?? 0), 0), color: classVar(c.id), icon: <ClassIcon classId={c.id} size={18} /> }))
    .filter((b) => b.value > 0)
    .sort((a, b) => b.value - a.value);
  const plates = [
    { value: fmtInt(total), label: 'Muertes con honor' },
    { value: fmtInt(fighters.length), label: 'Combatientes' },
    { value: fighters.length ? fmt1(total / fighters.length) : '—', label: 'Media por combatiente' },
    { value: fmtInt(top[0]?.honorableKills ?? 0), label: 'Récord individual' },
  ];

  return (
    <div>
      <PageBanner art={atmo.art} hue={atmo.hue} glow={atmo.glow} crest={<GuildCrest crest={o.guild.crest} name={o.guild.name} size={64} />} title="JcJ" subtitle={<>Actividad en combate contra jugadores de {o.guild.name} (reglas {o.guild.ruleset?.name ?? '—'})</>} aside={<ProvenanceNote provenance={o.provenance} />}>
        <dl className="mx-auto grid max-w-4xl grid-cols-2 gap-3 px-4 pb-8 sm:grid-cols-4">
          {plates.map((p, i) => (
            <div key={p.label} className="plate relative rounded-[3px] px-4 py-4 text-center">
              <FiligreeCorner id={`pvp${i}a`} size={18} className="pointer-events-none absolute left-0.5 top-0.5" />
              <FiligreeCorner id={`pvp${i}b`} size={18} className="pointer-events-none absolute bottom-0.5 right-0.5 -scale-100" />
              <dt className="sr-only">{p.label}</dt>
              <dd className="t-figure text-3xl text-[#f3e2b6]">{p.value}</dd>
              <dd className="mt-1 text-xs uppercase tracking-[0.16em] text-[#c8b68c]">{p.label}</dd>
            </div>
          ))}
        </dl>
      </PageBanner>

      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-10 sm:px-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <section aria-labelledby="pvp-top">
          <SectionHeading id="pvp-top" title="Mayores cazadores de honor">
            {fmtInt(known.length)} perfiles con resumen JcJ
          </SectionHeading>
          {top.length === 0 ? (
            <EmptyState className="mt-4" icon={Swords} title="Nadie ha conseguido muertes con honor todavía" />
          ) : (
            <ol className="frame-gold mt-4 divide-y divide-line/70 rounded-[4px]">
              {top.map((m, i) => (
                <li key={m.characterId} className="grid grid-cols-[2rem_minmax(0,1fr)_5rem] items-center gap-3 px-4 py-2.5 sm:grid-cols-[2rem_minmax(0,14rem)_1fr_5rem]">
                  <span className="t-num text-right text-fg-3">{i + 1}</span>
                  <Link href={characterHref(m.region, m.slug)} className="flex min-w-0 items-center gap-2.5">
                    <ClassIcon classId={m.classId} size={24} />
                    <span className="truncate font-semibold hover:underline" style={{ color: classVar(m.classId) }}>
                      {m.displayName}
                    </span>
                  </Link>
                  <span className="hidden h-1.5 rounded-r-[4px] bg-sunken sm:block" aria-hidden>
                    <span className="block h-full rounded-r-[4px]" style={{ width: `${((m.honorableKills ?? 0) / max) * 100}%`, background: classVar(m.classId) }} />
                  </span>
                  <span className="t-num text-right font-semibold">{fmtInt(m.honorableKills)}</span>
                </li>
              ))}
            </ol>
          )}
          <p className="mt-3 text-xs text-fg-3">
            Fuente: resumen JcJ de cada personaje en Battle.net (muertes con honor acumuladas). Los resultados de campos de batalla llegarán con el addon (Fase 6–7).
          </p>
        </section>
        <aside aria-labelledby="pvp-class">
          <SectionHeading id="pvp-class" title="Por clase" />
          <div className="mt-4">{byClass.length ? <RankedBars data={byClass} total={total} caption="Muertes con honor por clase" /> : <p className="text-sm text-fg-3">Sin datos.</p>}</div>
          <p className="mt-4 text-xs text-fg-3">Suma de muertes con honor por clase.</p>
        </aside>
      </div>
    </div>
  );
}
