import type { Metadata } from 'next';
import Link from 'next/link';
import type { CharacterArmoryDTO, Page, RosterMemberDTO } from '@blazonguild/types';
import { ItemTooltipBody } from '@/components/armory/ItemTooltip';
import { Embers, Parallax } from '@/components/art/Atmosphere';
import { FiligreeCorner, OrnateFrame, RuneDivider } from '@/components/art/Ornaments';
import { GOLD_TEXT, METAL, PARCHMENT, STONE } from '@/components/art/textures';
import { ClassIcon } from '@/components/game/bits';
import { GuildCrest } from '@/components/game/GuildCrest';
import { api, getGuildOverview, guildPath } from '@/lib/api';
import { fmt1, fmtInt } from '@/lib/format';
import { classById, classVar, specById } from '@/lib/game';

export const metadata: Metadata = { title: 'Laboratorio: direcciones visuales', robots: { index: false } };

const ART = (k: string) => `https://render.worldofwarcraft.com/eu/zones/${k}-small.jpg`;
const renderOf = (avatar: string | null) => (avatar ? avatar.replace(/-avatar\.jpg$/, '-main-raw.png') : null);

function GoldTitle({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return (
    <span
      className={`t-display inline-block bg-clip-text text-transparent ${className}`}
      style={{ backgroundImage: GOLD_TEXT, filter: 'drop-shadow(0 2px 0 rgba(0,0,0,.65)) drop-shadow(0 0 18px rgba(240,200,120,.25))' }}
    >
      {children}
    </span>
  );
}

function Render({ m, className = '', glow = true }: { m: RosterMemberDTO; className?: string; glow?: boolean }) {
  const src = renderOf(m.avatarUrl);
  if (!src) return null;
  return (
    <div className={`relative ${className}`}>
      <div aria-hidden className="absolute bottom-[6%] left-1/2 h-[7%] w-[60%] -translate-x-1/2 rounded-[50%] bg-black/70 blur-md" />
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={src}
        alt={m.displayName}
        className="absolute inset-0 h-full w-full select-none object-cover"
        style={{ objectPosition: '50% 56%', transform: 'scale(1.6)', filter: glow ? `drop-shadow(0 0 14px color-mix(in srgb, ${classVar(m.classId)} 55%, transparent))` : undefined }}
      />
    </div>
  );
}

function Plate({ value, label, id }: { value: string; label: string; id: string }) {
  return (
    <div className="relative overflow-hidden rounded-[3px] border border-black/80 px-5 py-4 shadow-[0_10px_30px_-10px_rgba(0,0,0,.9),inset_0_1px_0_rgba(255,255,255,.08)]" style={{ backgroundColor: '#1d2027', backgroundImage: `${METAL}, linear-gradient(180deg,#2a2e37,#14161b)`, backgroundBlendMode: 'overlay, normal' }}>
      <FiligreeCorner id={`${id}-a`} size={22} className="absolute left-0.5 top-0.5" />
      <FiligreeCorner id={`${id}-b`} size={22} className="absolute bottom-0.5 right-0.5 -scale-100" />
      <p className="t-figure text-3xl text-[#f3e2b6]">{value}</p>
      <p className="mt-1 text-xs uppercase tracking-[0.18em] text-[#b9a77e]">{label}</p>
    </div>
  );
}

export default async function DirectionsLab() {
  const [o, roster, gm] = await Promise.all([
    getGuildOverview('eu', 'forever'),
    api<Page<RosterMemberDTO>>(`${guildPath('eu', 'forever')}/roster?sort=level&dir=desc&pageSize=12`),
    api<CharacterArmoryDTO>('/v1/characters/eu/goa-smashie'),
  ]);
  const g = o.guild;
  const withRender = roster.items.filter((m) => m.avatarUrl);
  const trio = [withRender[1], withRender[0], withRender[2]].filter(Boolean) as RosterMemberDTO[];
  const hero = withRender.find((m) => m.slug === 'goa-smashie') ?? withRender[0];
  const weapon = gm.equipment.find((e) => e.slot === 'MAIN_HAND') ?? gm.equipment[0];
  const top = roster.items.slice(0, 6);
  const stats = [
    { value: fmtInt(o.stats.members), label: 'Personajes' },
    { value: fmtInt(o.stats.activeLast7d), label: 'Activos 7 días' },
    { value: fmt1(o.stats.averageLevel), label: 'Nivel medio' },
    { value: fmtInt(o.stats.maxLevel), label: 'Nivel máximo' },
  ];

  return (
    <div className="bg-[#07090d] text-[#e7eaf0]">
      <nav className="sticky top-0 z-50 flex flex-wrap items-center gap-2 border-b border-white/10 bg-black/80 px-4 py-2.5 text-sm backdrop-blur">
        <span className="mr-2 text-white/60">Laboratorio visual, con datos reales de «{g.name}»:</span>
        <a href="#a" className="rounded border border-[#c9a35a]/60 px-3 py-1 text-[#f0d79a] hover:bg-white/5">A · Híbrida</a>
        <a href="#b" className="rounded border border-[#c9a35a]/60 px-3 py-1 text-[#f0d79a] hover:bg-white/5">B · Interfaz del juego</a>
        <a href="#c" className="rounded border border-[#c9a35a]/60 px-3 py-1 text-[#f0d79a] hover:bg-white/5">C · Cinemática total</a>
        <Link href="/g/eu/forever" className="ml-auto text-white/50 hover:text-white">Volver a la web actual</Link>
      </nav>

      {/* ───────────────────────────── A · HÍBRIDA ───────────────────────────── */}
      <section id="a" className="scroll-mt-12">
        <Parallax className="relative isolate overflow-hidden" strength={14}>
          <div aria-hidden className="absolute inset-0 -z-20" data-depth="0.6">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={ART('molten-core')} alt="" className="h-[115%] w-[115%] -translate-x-[6%] -translate-y-[4%] object-cover opacity-60 blur-[2px] saturate-[1.15]" />
          </div>
          <div aria-hidden className="absolute inset-0 -z-10 bg-[radial-gradient(70%_60%_at_50%_45%,transparent_0%,rgba(7,9,13,.55)_55%,#07090d_100%)]" />
          <div aria-hidden className="absolute inset-x-0 bottom-0 -z-10 h-2/3 bg-gradient-to-t from-[#07090d] via-[#07090d]/80 to-transparent" />
          <Embers className="-z-10" density={80} />
          <div className="mx-auto flex max-w-6xl flex-col items-center px-4 pb-10 pt-12 text-center sm:pt-16">
            <p className="text-xs uppercase tracking-[0.4em] text-[#d8bd82]/80">Dirección A</p>
            <div className="relative mt-4">
              <div aria-hidden className="absolute -inset-5 rounded-full bg-[radial-gradient(circle,rgba(255,190,90,.35),transparent_65%)]" />
              <GuildCrest crest={g.crest} name={g.name} size={124} className="relative drop-shadow-[0_10px_30px_rgba(0,0,0,.9)]" />
            </div>
            <h1 className="mt-5">
              <GoldTitle className="text-6xl tracking-[0.06em] sm:text-8xl">{g.name}</GoldTitle>
            </h1>
            <p className="mt-2 text-sm tracking-[0.3em] text-[#e6d3a6]/80">HORDA · REGLAS {g.ruleset?.name.toUpperCase()} · EUROPA</p>
            <RuneDivider id="a-div" className="mt-5 max-w-md" />

            <div className="relative mt-2 flex h-[360px] w-full max-w-3xl items-end justify-center sm:h-[420px]" data-depth="-0.4">
              {trio.map((m, i) => (
                <div key={m.characterId} className={i === 1 ? 'z-10 -mx-6 flex h-full w-[44%] flex-col' : 'flex h-[82%] w-[34%] flex-col opacity-90'}>
                  <Render m={m} className="min-h-0 w-full flex-1" />
                  <p className="relative z-10 mt-1 text-sm font-semibold" style={{ color: classVar(m.classId), textShadow: '0 2px 6px #000' }}>
                    {m.displayName}
                    <span className="block text-xs font-normal text-white/60">
                      {specById(m.primarySpecId)?.nameEs ?? classById(m.classId)?.nameEs}, nivel {m.level}
                    </span>
                  </p>
                </div>
              ))}
            </div>

            <div className="mt-8 grid w-full max-w-4xl grid-cols-2 gap-3 sm:grid-cols-4">
              {stats.map((s, i) => (
                <Plate key={s.label} id={`pl${i}`} {...s} />
              ))}
            </div>
          </div>
        </Parallax>

        <div className="mx-auto grid max-w-6xl gap-8 px-4 pb-16 pt-6 lg:grid-cols-[340px_1fr]">
          <div>
            <p className="mb-2 text-sm text-white/50">Tooltip con marco ornamentado (objeto real de {gm.character.displayName})</p>
            <OrnateFrame id="tt" className="rounded-[4px] bg-[#0a0d1a]/95 p-5 shadow-[0_30px_60px_-20px_rgba(0,0,0,.9)]">
              {weapon && <ItemTooltipBody item={weapon} />}
            </OrnateFrame>
          </div>
          <div>
            <p className="mb-2 text-sm text-white/50">Los datos densos siguen limpios y legibles</p>
            <table className="w-full text-sm">
              <tbody>
                {top.map((m, i) => (
                  <tr key={m.characterId} className="border-b border-white/10">
                    <td className="t-num w-8 py-2 text-[#d8bd82]">{i + 1}</td>
                    <td className="py-2">
                      <span className="flex items-center gap-2.5">
                        <ClassIcon classId={m.classId} size={24} />
                        <span className="font-semibold" style={{ color: classVar(m.classId) }}>
                          {m.displayName}
                        </span>
                      </span>
                    </td>
                    <td className="py-2 text-white/60">{specById(m.primarySpecId)?.nameEs}</td>
                    <td className="t-num py-2 text-right font-semibold">{m.level}</td>
                    <td className="t-num py-2 text-right text-white/60">iLvl {m.itemLevel ?? '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* ──────────────────────── B · INTERFAZ DEL JUEGO ──────────────────────── */}
      <section id="b" className="relative scroll-mt-12 border-t-4 border-black" style={{ backgroundColor: '#77706a', backgroundImage: `${STONE}`, backgroundBlendMode: 'multiply' }}>
        <div aria-hidden className="absolute inset-0 bg-[radial-gradient(80%_70%_at_50%_40%,rgba(10,8,6,.25),rgba(10,8,6,.8))]" />
        <div className="relative mx-auto max-w-6xl px-4 py-14">
          <p className="text-center text-xs uppercase tracking-[0.4em] text-[#e8d6a8]/70">Dirección B</p>
          <div className="mt-6 grid gap-8 lg:grid-cols-[300px_1fr]">
            <div className="flex flex-col items-center gap-4">
              <div className="relative grid h-56 w-56 place-items-center rounded-full border-4 border-[#1a1612] shadow-[inset_0_0_30px_rgba(0,0,0,.9),0_10px_25px_rgba(0,0,0,.7)]" style={{ backgroundColor: '#4a443d', backgroundImage: STONE, backgroundBlendMode: 'multiply' }}>
                <div aria-hidden className="absolute inset-3 rounded-full border-2 border-[#c9a35a]/70" />
                <GuildCrest crest={g.crest} name={g.name} size={150} />
              </div>
              <h2 className="t-display text-4xl text-[#ffd479] [text-shadow:0_2px_0_#000,0_0_12px_rgba(0,0,0,.8)]">{g.name}</h2>
              <div className="flex gap-2">
                {['Roster', 'Raids', 'Rankings'].map((t) => (
                  <button key={t} type="button" className="rounded-[3px] border border-[#d6b45f] bg-gradient-to-b from-[#9b1c13] via-[#7a130d] to-[#4c0906] px-4 py-1.5 text-sm font-semibold text-[#ffd479] shadow-[inset_0_1px_0_rgba(255,200,150,.35),0_3px_6px_rgba(0,0,0,.6)] [text-shadow:0_1px_0_#000]">
                    {t}
                  </button>
                ))}
              </div>
            </div>
            <OrnateFrame id="pf" cornerSize={56} className="rounded-[4px] p-3 shadow-[0_20px_50px_rgba(0,0,0,.8)]" inner="rounded-[2px]">
              <div className="rounded-[2px] p-6 text-[#2b1d0e]" style={{ backgroundColor: '#e4d3ab', backgroundImage: `radial-gradient(120% 90% at 50% 40%, transparent 50%, rgba(110,70,30,.55) 100%), radial-gradient(30% 22% at 18% 28%, rgba(130,85,35,.16), transparent), radial-gradient(26% 20% at 84% 72%, rgba(130,85,35,.14), transparent), ${PARCHMENT}` }}>
                <h3 className="t-display text-center text-2xl text-[#6b1410]">Roster de la hermandad</h3>
                <div aria-hidden className="mx-auto mt-2 h-px max-w-xs bg-gradient-to-r from-transparent via-[#6b1410]/60 to-transparent" />
                <ul className="mt-3 divide-y divide-[#6b4a22]/25">
                  {top.map((m) => (
                    <li key={m.characterId} className="flex items-center gap-3 py-2">
                      <ClassIcon classId={m.classId} size={28} />
                      <span className="font-semibold">{m.displayName}</span>
                      <span className="text-sm text-[#5a4127]">{classById(m.classId)?.nameEs}</span>
                      <span className="t-num ml-auto font-semibold">Nivel {m.level}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </OrnateFrame>
          </div>
        </div>
      </section>

      {/* ───────────────────────── C · CINEMÁTICA TOTAL ───────────────────────── */}
      <section id="c" className="scroll-mt-12">
        <Parallax className="relative isolate flex min-h-[100svh] items-center overflow-hidden" strength={26}>
          <div aria-hidden className="absolute inset-0 -z-20" data-depth="0.5">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={ART('naxxramas')} alt="" className="h-[120%] w-[120%] -translate-x-[8%] -translate-y-[6%] object-cover opacity-70 blur-[3px] hue-rotate-[-10deg] saturate-[1.3]" />
          </div>
          <div aria-hidden className="absolute inset-0 -z-10 bg-gradient-to-r from-[#05070a] via-[#05070a]/70 to-transparent" />
          <div aria-hidden className="absolute inset-x-0 bottom-0 -z-10 h-1/2 bg-gradient-to-t from-[#05070a] to-transparent" />
          <Embers className="-z-10" density={40} hue={190} />
          {hero && (
            <div aria-hidden className="absolute -right-[10%] bottom-0 top-[4%] -z-10 w-[70%] max-w-[900px]" data-depth="-1.2">
              <Render m={hero} className="h-full w-full" />
            </div>
          )}
          <div className="relative mx-auto w-full max-w-6xl px-4 py-24">
            <p className="text-xs uppercase tracking-[0.5em] text-cyan-100/60">Dirección C</p>
            <h2 className="mt-4 max-w-xl">
              <GoldTitle className="text-7xl leading-[0.95] tracking-[0.04em] sm:text-9xl">{g.name}</GoldTitle>
            </h2>
            <p className="mt-6 max-w-md text-lg text-white/75">{hero?.displayName} lidera a {o.stats.members} personajes de la Horda en las reglas {g.ruleset?.name}.</p>
            <div className="mt-10 flex max-w-xl flex-wrap gap-px overflow-hidden rounded-md border border-white/15 bg-white/10 backdrop-blur-md">
              {stats.map((s) => (
                <div key={s.label} className="min-w-[45%] flex-1 bg-black/40 px-5 py-4">
                  <p className="t-figure text-3xl text-white">{s.value}</p>
                  <p className="text-xs uppercase tracking-[0.2em] text-white/55">{s.label}</p>
                </div>
              ))}
            </div>
            <p className="mt-16 animate-bounce text-sm text-white/50">Descubre la hermandad ↓</p>
          </div>
        </Parallax>
        <div className="relative isolate overflow-hidden">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={ART('blackwing-lair')} alt="" className="absolute inset-0 -z-10 h-full w-full object-cover opacity-40 blur-[2px]" />
          <div aria-hidden className="absolute inset-0 -z-10 bg-gradient-to-b from-[#05070a] via-transparent to-[#05070a]" />
          <div className="mx-auto max-w-6xl px-4 py-24">
            <h3 className="t-display text-4xl text-white">Guarida de Alanegra</h3>
            <p className="mt-3 max-w-lg text-white/70">Así se presentaría cada sección: una escena con el arte oficial de la banda y el mínimo texto encima.</p>
          </div>
        </div>
      </section>
    </div>
  );
}
