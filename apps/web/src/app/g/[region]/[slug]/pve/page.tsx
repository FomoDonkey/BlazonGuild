import type { Metadata } from 'next';
import Link from 'next/link';
import { Lock, Skull } from 'lucide-react';
import type { Page, RaidSummaryDTO, RosterMemberDTO, ViewerContextDTO } from '@blazonguild/types';
import { PageBanner } from '@/components/art/CinematicHero';
import { FiligreeCorner } from '@/components/art/Ornaments';
import { zoneArt } from '@/components/art/raid-art';
import { GuildCrest } from '@/components/game/GuildCrest';
import { EmptyState, ProvenanceNote, SectionHeading } from '@/components/ui/states';
import { api, ApiFailure, getGuildOverview, guildPath } from '@/lib/api';
import { fmtDate, fmtInt } from '@/lib/format';
import { guildHref } from '@/lib/game';

type Props = { params: Promise<{ region: string; slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug).catch(() => null);
  return { title: o ? `JcE de ${o.guild.name}` : 'JcE' };
}

/** Raid catalogue of the classic era (reference data: name, size, entry level). */
const RAIDS = [
  { key: 'MC', name: 'Núcleo de Magma', size: 40, level: 60 },
  { key: 'ONY', name: 'Guarida de Onyxia', size: 40, level: 60 },
  { key: 'BWL', name: 'Guarida de Alanegra', size: 40, level: 60 },
  { key: 'ZG', name: "Zul'Gurub", size: 20, level: 58 },
  { key: 'AQ20', name: "Ruinas de Ahn'Qiraj", size: 20, level: 60 },
  { key: 'AQ40', name: "Templo de Ahn'Qiraj", size: 40, level: 60 },
  { key: 'NAXX', name: 'Naxxramas', size: 40, level: 60 },
];

export default async function PvePage({ params }: Props) {
  const { region, slug } = await params;
  const base = guildPath(region, slug);
  const [o, roster] = await Promise.all([getGuildOverview(region, slug), api<Page<RosterMemberDTO>>(`${base}/roster?pageSize=500`)]);
  let past: RaidSummaryDTO[] | null = null;
  try {
    past = (await api<{ viewer: ViewerContextDTO; raids: RaidSummaryDTO[] }>(`${base}/raids?scope=past`)).raids;
  } catch (err) {
    if (!(err instanceof ApiFailure && (err.status === 401 || err.status === 403))) throw err;
  }
  const levels = roster.items.map((m) => m.level);
  const ready = (min: number) => levels.filter((l) => l >= min).length;
  const plates = [
    { value: fmtInt(ready(60)), label: 'Nivel 60', note: 'listos para banda' },
    { value: fmtInt(levels.filter((l) => l >= 55 && l < 60).length), label: 'Nivel 55–59', note: 'a punto' },
    { value: fmtInt(levels.filter((l) => l >= 45 && l < 55).length), label: 'Nivel 45–54', note: 'mazmorras de nivel alto' },
    { value: fmtInt(levels.filter((l) => l < 45).length), label: 'Por debajo de 45', note: 'subiendo' },
  ];
  const completed = (key: string) => past?.filter((r) => r.instanceKey === key && r.status === 'COMPLETED') ?? [];

  return (
    <div>
      <PageBanner art={zoneArt('BWL')} hue={18} glow="rgba(255,110,60,.25)" crest={<GuildCrest crest={o.guild.crest} name={o.guild.name} size={64} />} title="JcE" subtitle={<>Preparación y progreso de banda de {o.guild.name}</>} aside={<ProvenanceNote provenance={o.provenance} />}>
        <dl className="mx-auto grid max-w-4xl grid-cols-2 gap-3 px-4 pb-8 sm:grid-cols-4">
          {plates.map((p, i) => (
            <div key={p.label} className="plate relative rounded-[3px] px-4 py-4 text-center">
              <FiligreeCorner id={`pve${i}a`} size={18} className="pointer-events-none absolute left-0.5 top-0.5" />
              <FiligreeCorner id={`pve${i}b`} size={18} className="pointer-events-none absolute bottom-0.5 right-0.5 -scale-100" />
              <dt className="sr-only">{p.label}</dt>
              <dd className="t-figure text-3xl text-[#f3e2b6]">{p.value}</dd>
              <dd className="mt-1 text-xs uppercase tracking-[0.16em] text-[#c8b68c]">{p.label}</dd>
              <dd className="text-xs text-white/45">{p.note}</dd>
            </div>
          ))}
        </dl>
      </PageBanner>

      <div className="mx-auto max-w-6xl space-y-12 px-4 py-10 sm:px-6">
        <section aria-labelledby="raids">
          <SectionHeading id="raids" title="Bandas">
            Requisitos y tamaño según el juego clásico
          </SectionHeading>
          <ul className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {RAIDS.map((r) => {
              const done = completed(r.key);
              const eligible = ready(r.level);
              return (
                <li key={r.key}>
                  <article className="cinematic frame-gold group relative isolate flex h-48 flex-col justify-end overflow-hidden rounded-[4px] p-4">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={zoneArt(r.key)} alt="" aria-hidden className="absolute inset-0 -z-20 h-full w-full object-cover opacity-75 transition-transform duration-700 group-hover:scale-105" />
                    <span aria-hidden className="absolute inset-0 -z-10 bg-gradient-to-t from-[#07090d] via-[#07090d]/70 to-transparent" />
                    <h3 className="t-display text-xl text-white [text-shadow:0_2px_6px_#000]">{r.name}</h3>
                    <p className="t-num mt-0.5 text-sm text-white/70">
                      {r.size} jugadores, nivel {r.level}
                    </p>
                    <p className="mt-2 flex flex-wrap gap-x-4 text-xs">
                      <span className={eligible >= r.size ? 'text-success' : 'text-warning'}>
                        {fmtInt(eligible)} de la hermandad con nivel suficiente
                      </span>
                      {past !== null && <span className="text-white/60">{done.length ? `${done.length} ${done.length === 1 ? 'raid completada' : 'raids completadas'}` : 'Sin raids completadas'}</span>}
                    </p>
                  </article>
                </li>
              );
            })}
          </ul>
        </section>

        <section aria-labelledby="bosses">
          <SectionHeading id="bosses" title="Progreso jefe a jefe" />
          <EmptyState className="mt-4" icon={Skull} title="Todavía sin datos de encuentros">
            Battle.net aún no publica encuentros de banda en World of Warcraft: Forever (el endpoint responde vacío). El progreso por jefe, las primeras muertes y los intentos llegarán con los registros de combate (Fase 5) o en cuanto Blizzard los publique.
          </EmptyState>
        </section>

        <section aria-labelledby="history">
          <SectionHeading id="history" title="Historial de raids" />
          {past === null ? (
            <EmptyState className="mt-4" icon={Lock} title="Solo para miembros">
              El historial de convocatorias es privado de cada hermandad.
            </EmptyState>
          ) : past.length === 0 ? (
            <EmptyState className="mt-4" title="Aún no hay raids pasadas" action={{ href: guildHref(region, slug, '/raids'), label: 'Ir a Raids' }} />
          ) : (
            <ul className="frame-gold mt-4 divide-y divide-line/70 rounded-[4px]">
              {past.slice(0, 20).map((r) => (
                <li key={r.id}>
                  <Link href={guildHref(region, slug, `/raids/${r.id}`)} className="flex items-center justify-between gap-3 px-4 py-3 hover:bg-white/[0.03]">
                    <span>
                      <span className="font-medium">{r.title}</span>
                      <span className="block text-xs text-fg-3">
                        {r.instanceName}, {fmtDate(r.startsAt)}
                      </span>
                    </span>
                    <span className="t-num text-sm text-fg-2">{r.counts.confirmed} confirmados</span>
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
