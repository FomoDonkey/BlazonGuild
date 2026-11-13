import Link from 'next/link';
import { iconUrl, type CombatRole, type Faction } from '@blazonguild/types';
import { Shield, Cross, Swords } from 'lucide-react';
import { characterHref, classById, classVar, FACTION_LABEL, ROLE_LABEL } from '@/lib/game';
import { cn } from '@/lib/utils';

/** Official class icon from the Battle.net render CDN, framed in the class colour. */
export function ClassIcon({ classId, size = 24, className }: { classId: number; size?: number; className?: string }) {
  const cls = classById(classId);
  if (!cls) return null;
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={iconUrl(cls.iconFileId, size > 36 ? 56 : 36)}
      alt=""
      width={size}
      height={size}
      loading="lazy"
      className={cn('shrink-0 rounded-sm ring-1', className)}
      style={{ ['--tw-ring-color' as string]: classVar(classId) }}
      title={cls.nameEs}
    />
  );
}

export { ItemIcon } from './ItemIcon';

export function CharacterLink({
  region,
  slug,
  name,
  classId,
  className,
}: {
  region: string;
  slug: string;
  name: string;
  classId: number;
  className?: string;
}) {
  return (
    <Link href={characterHref(region, slug)} className={cn('font-semibold hover:underline underline-offset-4', className)} style={{ color: classVar(classId) }}>
      {name}
    </Link>
  );
}

export function RoleIcon({ role, className }: { role: CombatRole | null; className?: string }) {
  if (!role) return null;
  const Icon = role === 'TANK' ? Shield : role === 'HEALER' ? Cross : Swords;
  return (
    <span title={ROLE_LABEL[role]} className={cn('inline-flex items-center', className)}>
      <Icon className="h-3.5 w-3.5" aria-hidden />
      <span className="sr-only">{ROLE_LABEL[role]}</span>
    </span>
  );
}

export function FactionMark({ faction, className }: { faction: Faction | null; className?: string }) {
  if (!faction) return null;
  return (
    <span className={cn('inline-flex items-center gap-1.5 text-sm font-medium', faction === 'HORDE' ? 'text-horde' : 'text-alliance', className)}>
      <span aria-hidden className={cn('h-2 w-2 rotate-45', faction === 'HORDE' ? 'bg-horde' : 'bg-alliance')} />
      {FACTION_LABEL[faction]}
    </span>
  );
}

/** Talent distribution like the in-game "5/2/36" readout; the dominant tree is emphasised. */
export function TalentSplit({ split, className }: { split: number[] | null; className?: string }) {
  if (!split) return <span className="text-fg-3">—</span>;
  const max = Math.max(...split);
  return (
    <span className={cn('t-num whitespace-nowrap text-fg-2', className)} aria-label={`Talentos ${split.join(' / ')}`}>
      {split.map((n, i) => (
        <span key={i}>
          {i > 0 && <span className="px-0.5 text-fg-3">/</span>}
          <span className={n === max && n > 0 ? 'font-semibold text-fg' : undefined}>{n}</span>
        </span>
      ))}
    </span>
  );
}

export function Coins({ gold, silver, copper }: { gold: number; silver: number; copper: number }) {
  const coin = (n: number, color: string, label: string) =>
    n > 0 ? (
      <span className="inline-flex items-center gap-1">
        <span className="t-num">{n}</span>
        <span aria-hidden className="inline-block h-2.5 w-2.5 rounded-full" style={{ background: color, boxShadow: 'inset 0 -1px 0 rgb(0 0 0 / .35)' }} />
        <span className="sr-only">{label}</span>
      </span>
    ) : null;
  return (
    <span className="inline-flex items-center gap-2">
      {coin(gold, '#e8c34a', 'oro')}
      {coin(silver, '#c9ced6', 'plata')}
      {coin(copper, '#c07a43', 'cobre')}
    </span>
  );
}
