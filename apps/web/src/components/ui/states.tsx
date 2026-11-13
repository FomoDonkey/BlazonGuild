import Link from 'next/link';
import type { Provenance } from '@blazonguild/types';
import { PROVENANCE_LABEL } from '@blazonguild/types';
import { AlertTriangle, BadgeCheck, CircleDashed, FlaskConical, Hand, Sigma, type LucideIcon } from 'lucide-react';
import { fmtDateTime, relativeTime } from '@/lib/format';
import { cn } from '@/lib/utils';

const SOURCE_ICON: Record<string, LucideIcon> = {
  BLIZZARD_API: BadgeCheck,
  ADDON_COLLECTED: FlaskConical,
  COMBAT_LOG: Sigma,
  MANUAL: Hand,
  CALCULATED: Sigma,
  ESTIMATED: CircleDashed,
  UNAVAILABLE: CircleDashed,
};

/** Data provenance: where a value comes from, how sure we are and when it was captured (ADR-003). */
export function ProvenanceNote({ provenance, className, compact }: { provenance: Provenance; className?: string; compact?: boolean }) {
  const Icon = SOURCE_ICON[provenance.source] ?? BadgeCheck;
  const verified = provenance.status === 'VERIFIED' || provenance.status === 'DERIVED';
  const when = provenance.collectedAt ? relativeTime(provenance.collectedAt) : null;
  const title = [
    `Fuente: ${PROVENANCE_LABEL[provenance.source]}`,
    `Confianza: ${Math.round(provenance.confidence * 100)} %`,
    provenance.collectedAt ? `Capturado: ${fmtDateTime(provenance.collectedAt)}` : null,
    provenance.endpoint ? `Origen: ${provenance.endpoint}` : null,
    provenance.notes ?? null,
  ]
    .filter(Boolean)
    .join('\n');
  return (
    <span className={cn('inline-flex items-center gap-1.5 text-xs', verified ? 'text-fg-2' : 'text-warning', className)} title={title}>
      <Icon className={cn('h-3.5 w-3.5', verified ? 'text-success' : 'text-warning')} aria-hidden />
      <span>
        {PROVENANCE_LABEL[provenance.source]}
        {!compact && when ? <span className="text-fg-3">, {when}</span> : null}
      </span>
    </span>
  );
}

export function EmptyState({
  icon: Icon = CircleDashed,
  title,
  children,
  action,
  className,
}: {
  icon?: LucideIcon;
  title: string;
  children?: React.ReactNode;
  action?: { href: string; label: string };
  className?: string;
}) {
  return (
    <div className={cn('flex flex-col items-start gap-2 rounded-md border border-dashed border-line-strong/60 px-5 py-6', className)}>
      <Icon className="h-5 w-5 text-fg-3" aria-hidden />
      <p className="font-medium text-fg">{title}</p>
      {children ? <div className="max-w-prose text-sm text-fg-2">{children}</div> : null}
      {action ? (
        <Link href={action.href} className="btn-secondary mt-1">
          {action.label}
        </Link>
      ) : null}
    </div>
  );
}

export function ErrorPanel({ title, message, children }: { title: string; message: string; children?: React.ReactNode }) {
  return (
    <div role="alert" className="flex gap-3 rounded-md border border-danger/40 bg-danger/5 px-5 py-4">
      <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0 text-danger" aria-hidden />
      <div className="space-y-1">
        <p className="font-medium text-fg">{title}</p>
        <p className="text-sm text-fg-2">{message}</p>
        {children}
      </div>
    </div>
  );
}

export function SectionHeading({ title, children, as: As = 'h2', className, id }: { title: string; children?: React.ReactNode; as?: 'h2' | 'h3'; className?: string; id?: string }) {
  return (
    <div className={cn('relative flex flex-wrap items-end justify-between gap-x-4 gap-y-1 pb-2', className)}>
      <As id={id} className="t-display text-xl leading-tight">
        <span aria-hidden className="mr-2 inline-block h-2 w-2 -translate-y-0.5 rotate-45 border border-accent/80 bg-accent/30" />
        {title}
      </As>
      {children ? <div className="text-sm text-fg-2">{children}</div> : null}
      <span aria-hidden className="rule-gold absolute inset-x-0 bottom-0 opacity-40" />
    </div>
  );
}

export function Meter({ value, max, className, color }: { value: number; max: number; className?: string; color?: string }) {
  const pct = max > 0 ? Math.min(100, (value / max) * 100) : 0;
  return (
    <span className={cn('block h-1.5 overflow-hidden rounded-full bg-sunken', className)} aria-hidden>
      <span className="block h-full rounded-full" style={{ width: `${pct}%`, background: color ?? 'rgb(var(--c-accent))' }} />
    </span>
  );
}
