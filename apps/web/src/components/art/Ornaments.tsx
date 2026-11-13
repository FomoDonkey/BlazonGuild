import { cn } from '@/lib/utils';

/** Shared gold gradient definition (render once per SVG — ids are scoped per instance). */
function GoldDefs({ id }: { id: string }) {
  return (
    <defs>
      <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stopColor="#fff1c8" />
        <stop offset=".35" stopColor="#d9b56a" />
        <stop offset=".6" stopColor="#8f6a2b" />
        <stop offset="1" stopColor="#f0d18a" />
      </linearGradient>
    </defs>
  );
}

/** Original filigree corner: double rail, scroll curl and leaf, drawn for BlazonGuild. */
export function FiligreeCorner({ className, id = 'fc', size = 44 }: { className?: string; id?: string; size?: number }) {
  return (
    <svg viewBox="0 0 72 72" width={size} height={size} className={className} aria-hidden>
      <GoldDefs id={id} />
      <g fill="none" stroke={`url(#${id})`} strokeLinecap="round">
        <path d="M3 70V18Q3 3 18 3h52" strokeWidth="2" />
        <path d="M9 70V22Q9 9 22 9h48" strokeWidth=".9" opacity=".75" />
        <path d="M18 18c9 0 15 5 16 14-5-4-10-4-13 1-1-7-5-11-12-11 3-1 6-2 9-4z" fill={`url(#${id})`} stroke="none" />
        <path d="M30 3c4 4 4 9 0 12M3 30c4 4 9 4 12 0" strokeWidth="1.2" />
        <circle cx="15" cy="15" r="3.2" fill={`url(#${id})`} stroke="none" />
        <circle cx="40" cy="6" r="1.4" fill={`url(#${id})`} stroke="none" />
        <circle cx="6" cy="40" r="1.4" fill={`url(#${id})`} stroke="none" />
      </g>
    </svg>
  );
}

/** Panel with filigree corners and a hairline gold rail. */
export function OrnateFrame({ children, className, inner, cornerSize = 44, id = 'of' }: { children: React.ReactNode; className?: string; inner?: string; cornerSize?: number; id?: string }) {
  return (
    <div className={cn('relative', className)}>
      <div aria-hidden className="pointer-events-none absolute inset-[6px] rounded-[3px] border border-[#c9a35a]/45" />
      <div aria-hidden className="pointer-events-none absolute inset-0 rounded-[4px] border border-black/70 shadow-[inset_0_0_0_1px_rgba(255,232,180,.06)]" />
      <FiligreeCorner size={cornerSize} id={`${id}-tl`} className="pointer-events-none absolute left-0 top-0" />
      <FiligreeCorner size={cornerSize} id={`${id}-tr`} className="pointer-events-none absolute right-0 top-0 -scale-x-100" />
      <FiligreeCorner size={cornerSize} id={`${id}-bl`} className="pointer-events-none absolute bottom-0 left-0 -scale-y-100" />
      <FiligreeCorner size={cornerSize} id={`${id}-br`} className="pointer-events-none absolute bottom-0 right-0 -scale-100" />
      <div className={cn('relative', inner)}>{children}</div>
    </div>
  );
}

/** Section divider: rails fading out with a central lozenge, like an illuminated manuscript rule. */
export function RuneDivider({ className, id = 'rd' }: { className?: string; id?: string }) {
  return (
    <svg viewBox="0 0 400 24" preserveAspectRatio="none" className={cn('h-6 w-full', className)} aria-hidden>
      <defs>
        <linearGradient id={id} x1="0" x2="1">
          <stop offset="0" stopColor="#c9a35a" stopOpacity="0" />
          <stop offset=".42" stopColor="#e9cd8b" />
          <stop offset=".58" stopColor="#e9cd8b" />
          <stop offset="1" stopColor="#c9a35a" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d="M0 12H178M222 12H400" stroke={`url(#${id})`} strokeWidth="1.2" />
      <path d="M0 16H170M230 16H400" stroke={`url(#${id})`} strokeWidth=".5" opacity=".6" />
      <path d="M200 2l10 10-10 10-10-10z" fill="none" stroke="#e9cd8b" strokeWidth="1.4" />
      <path d="M200 7l5 5-5 5-5-5z" fill="#e9cd8b" />
      <circle cx="183" cy="12" r="2" fill="#e9cd8b" />
      <circle cx="217" cy="12" r="2" fill="#e9cd8b" />
    </svg>
  );
}
