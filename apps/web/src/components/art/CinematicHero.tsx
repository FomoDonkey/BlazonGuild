import type { RosterMemberDTO } from '@blazonguild/types';
import Link from 'next/link';
import { characterHref, classById, classVar, specById } from '@/lib/game';
import { cn } from '@/lib/utils';
import { Embers, Parallax } from './Atmosphere';

/**
 * Cinematic stage used by the Hybrid direction: official instance artwork, colour grading,
 * drifting fog, embers and pointer parallax. Always rendered with the dark palette (`.cinematic`).
 */
export function CinematicHero({
  art,
  hue = 28,
  glow = 'rgba(255,150,60,.3)',
  children,
  className,
  embers = 70,
  artOpacity = 0.55,
}: {
  art: string;
  hue?: number;
  glow?: string;
  children: React.ReactNode;
  className?: string;
  embers?: number;
  artOpacity?: number;
}) {
  return (
    <Parallax className={cn('cinematic relative isolate overflow-hidden bg-[#07090d] text-fg', className)} strength={12}>
      <div aria-hidden className="absolute inset-0 -z-30" data-depth="0.5">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={art} alt="" className="h-[118%] w-[118%] -translate-x-[7%] -translate-y-[6%] object-cover blur-[2px] saturate-[1.15]" style={{ opacity: artOpacity }} />
      </div>
      <div aria-hidden className="absolute inset-0 -z-20" style={{ background: `radial-gradient(60% 55% at 50% 38%, ${glow}, transparent 70%)` }} />
      <div aria-hidden className="absolute inset-0 -z-20 bg-[radial-gradient(80%_70%_at_50%_40%,transparent_0%,rgba(7,9,13,.55)_55%,rgba(7,9,13,.95)_100%)]" />
      <div aria-hidden className="absolute inset-x-0 bottom-0 -z-20 h-1/2 bg-gradient-to-t from-canvas via-canvas/70 to-transparent" />
      <div aria-hidden className="fog absolute inset-x-[-20%] bottom-[8%] -z-10 h-48" />
      <Embers className="-z-10" density={embers} hue={hue} />
      {children}
    </Parallax>
  );
}

/** Real 3D renders staggered around the leader, like a guild portrait on a stage. */
export function Lineup({ members, className }: { members: RosterMemberDTO[]; className?: string }) {
  if (!members.length) return null;
  // Leader in the middle, the rest alternating outwards.
  const order: RosterMemberDTO[] = [];
  members.forEach((m, i) => (i % 2 === 0 ? order.push(m) : order.unshift(m)));
  const leaderIdx = order.indexOf(members[0]);
  return (
    <ul className={cn('relative flex items-end justify-center', className)} aria-label="Personajes destacados">
      {order.map((m, i) => {
        const dist = Math.abs(i - leaderIdx);
        const size = dist === 0 ? 'flex h-full w-[38%] sm:w-[30%]' : dist === 1 ? 'hidden h-[82%] w-[24%] sm:flex' : 'hidden h-[66%] w-[18%] lg:flex';
        return (
          <li key={m.characterId} className={cn('relative -mx-[3%] flex-col', size, dist === 0 ? 'z-20' : dist === 1 ? 'z-10 opacity-90' : 'opacity-75')} data-depth={dist === 0 ? '-0.6' : dist === 1 ? '-0.35' : '-0.15'} style={{ ['--cls' as string]: classVar(m.classId) }}>
            <Link href={characterHref(m.region, m.slug)} className="group relative block min-h-0 flex-1" aria-label={`${m.displayName}, ${classById(m.classId)?.nameEs} de nivel ${m.level}`}>
              <span aria-hidden className="absolute bottom-[5%] left-1/2 h-[7%] w-[62%] -translate-x-1/2 rounded-[50%] bg-black/75 blur-md" />
              {m.renderUrl && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={m.renderUrl} alt="" loading={dist === 0 ? 'eager' : 'lazy'} className="glow-class absolute inset-0 h-full w-full select-none object-cover transition-transform duration-500 group-hover:-translate-y-1 group-hover:scale-[1.02]" style={{ objectPosition: '50% 56%', transform: 'scale(1.6)' }} />
              )}
            </Link>
            <p className="relative z-10 -mt-2 text-center text-sm font-semibold leading-tight [text-shadow:0_2px_8px_#000]" style={{ color: classVar(m.classId) }}>
              {m.displayName}
              <span className="block text-xs font-normal text-white/60">
                {m.rankIndex === 0 ? 'Maestro de la hermandad' : `${specById(m.primarySpecId)?.nameEs ?? classById(m.classId)?.nameEs}, nivel ${m.level}`}
              </span>
            </p>
          </li>
        );
      })}
    </ul>
  );
}

/** Compact cinematic banner for inner pages (roster, rankings, raids…). */
export function PageBanner({
  art,
  hue,
  glow,
  title,
  subtitle,
  crest,
  aside,
  children,
}: {
  art: string;
  hue?: number;
  glow?: string;
  title: string;
  subtitle?: React.ReactNode;
  crest?: React.ReactNode;
  aside?: React.ReactNode;
  children?: React.ReactNode;
}) {
  return (
    <CinematicHero art={art} hue={hue} glow={glow} embers={30} artOpacity={0.45} className="border-b border-black">
      <div className="mx-auto flex max-w-7xl flex-col gap-4 px-4 pb-6 pt-8 sm:px-6 sm:pt-10 lg:flex-row lg:items-end lg:justify-between">
        <div className="flex items-center gap-4">
          {crest}
          <div>
            <h1>
              <span className="t-display text-gold inline-block text-4xl leading-tight sm:text-5xl">{title}</span>
            </h1>
            {subtitle && <p className="mt-1 text-white/70">{subtitle}</p>}
          </div>
        </div>
        {aside && <div className="text-white/70">{aside}</div>}
      </div>
      {children}
    </CinematicHero>
  );
}
