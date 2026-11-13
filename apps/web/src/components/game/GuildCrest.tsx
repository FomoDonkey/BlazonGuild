import type { GuildCrestDTO } from '@blazonguild/types';
import { cn } from '@/lib/utils';

/**
 * Heraldic medallion built from the guild's real Battle.net crest data:
 * background colour + emblem (tinted through a CSS mask) + border colour rings.
 * The medallion frame is original BlazonGuild artwork; only the emblem shape comes from Blizzard.
 */
export function GuildCrest({
  crest,
  name,
  size = 56,
  sizeClass,
  className,
}: {
  crest: GuildCrestDTO | null;
  name: string;
  size?: number;
  /** Responsive size via classes (e.g. "h-20 w-20 sm:h-28 sm:w-28"); overrides `size`. */
  sizeClass?: string;
  className?: string;
}) {
  // Without Blizzard crest data the medallion stays dark metal in both themes so the gold initial reads.
  const bg = crest?.backgroundColor ?? '#1d232d';
  const ring = crest?.borderColor ?? 'rgb(var(--c-accent))';
  const emblem = crest?.emblemColor ?? 'rgb(var(--c-text-2))';
  const initial = name.trim().charAt(0).toUpperCase();
  return (
    <span
      role="img"
      aria-label={`Emblema de ${name}`}
      className={cn('relative inline-grid shrink-0 place-items-center rounded-full', sizeClass, className)}
      style={sizeClass ? undefined : { width: size, height: size }}
    >
      <svg viewBox="0 0 100 100" className="absolute inset-0 h-full w-full" aria-hidden>
        <defs>
          <radialGradient id="crest-shade" cx="50%" cy="38%" r="62%">
            <stop offset="0%" stopColor="#fff" stopOpacity="0.18" />
            <stop offset="70%" stopColor="#000" stopOpacity="0" />
            <stop offset="100%" stopColor="#000" stopOpacity="0.45" />
          </radialGradient>
        </defs>
        <circle cx="50" cy="50" r="48" fill={ring} />
        <circle cx="50" cy="50" r="44.5" fill="#0b0e13" />
        <circle cx="50" cy="50" r="42" fill={bg} />
        <circle cx="50" cy="50" r="42" fill="url(#crest-shade)" />
        <circle cx="50" cy="50" r="38" fill="none" stroke={ring} strokeOpacity="0.55" strokeWidth="0.8" />
      </svg>
      {crest?.emblemUrl ? (
        <span
          aria-hidden
          className="relative"
          style={{
            width: '62%',
            height: '62%',
            backgroundColor: emblem,
            WebkitMaskImage: `url("${crest.emblemUrl}")`,
            maskImage: `url("${crest.emblemUrl}")`,
            WebkitMaskSize: 'contain',
            maskSize: 'contain',
            WebkitMaskRepeat: 'no-repeat',
            maskRepeat: 'no-repeat',
            WebkitMaskPosition: 'center',
            maskPosition: 'center',
            filter: 'drop-shadow(0 1px 1px rgb(0 0 0 / 0.5))',
          }}
        />
      ) : (
        <span aria-hidden className="t-display relative text-[#ecd9a4]" style={{ fontSize: size * 0.42 }}>
          {initial}
        </span>
      )}
    </span>
  );
}
