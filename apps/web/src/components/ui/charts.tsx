'use client';

import { useState } from 'react';
import { cn } from '@/lib/utils';

export interface BarDatum {
  key: string;
  label: string;
  value: number;
  /** Identity colour of the entity (e.g. class colour). Never used for text. */
  color?: string;
  icon?: React.ReactNode;
  hint?: string;
}

/**
 * Horizontal ranked bars with direct labels (icon + name + value): identity is never colour-only.
 * Thin marks, 4px rounded data-end, recessive track. Hover/focus reveals the share.
 */
export function RankedBars({ data, total, caption, unit = '' }: { data: BarDatum[]; total: number; caption: string; unit?: string }) {
  const max = Math.max(1, ...data.map((d) => d.value));
  return (
    <figure>
      <ul className="space-y-2">
        {data.map((d) => {
          const share = total > 0 ? Math.round((d.value / total) * 100) : 0;
          return (
            <li key={d.key} className="group grid grid-cols-[minmax(0,9.5rem)_1fr_2.5rem] items-center gap-3" title={`${d.label}: ${d.value}${unit} (${share} %)`}>
              <span className="flex min-w-0 items-center gap-2 text-sm text-fg-2">
                {d.icon}
                <span className="truncate">{d.label}</span>
              </span>
              <span className="relative block h-2.5 rounded-r-[4px] bg-sunken" aria-hidden>
                <span
                  className="absolute inset-y-0 left-0 rounded-r-[4px] transition-[filter] group-hover:brightness-110"
                  style={{ width: `${(d.value / max) * 100}%`, background: d.color ?? 'rgb(var(--c-accent))' }}
                />
              </span>
              <span className="t-num text-right text-sm text-fg">{d.value}</span>
            </li>
          );
        })}
      </ul>
      <table className="sr-only">
        <caption>{caption}</caption>
        <thead>
          <tr>
            <th>Categoría</th>
            <th>Valor</th>
          </tr>
        </thead>
        <tbody>
          {data.map((d) => (
            <tr key={d.key}>
              <td>{d.label}</td>
              <td>{d.value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  );
}

/** Single-series column histogram (one hue, no legend; the title names the series). */
export function Histogram({ data, caption, height = 120, unitLabel }: { data: BarDatum[]; caption: string; height?: number; unitLabel: string }) {
  const [hover, setHover] = useState<number | null>(null);
  const max = Math.max(1, ...data.map((d) => d.value));
  const active = hover !== null ? data[hover] : null;
  return (
    <figure className="relative">
      <div className="relative" style={{ height }}>
        {/* recessive baseline + half grid */}
        <div aria-hidden className="absolute inset-x-0 bottom-0 border-t border-line" />
        <div aria-hidden className="absolute inset-x-0 border-t border-dashed border-line/60" style={{ bottom: height / 2 }} />
        <div className="absolute inset-0 flex items-end gap-[2px]">
          {data.map((d, i) => (
            <button
              key={d.key}
              type="button"
              className="group relative flex h-full flex-1 items-end focus-visible:outline-offset-0"
              onMouseEnter={() => setHover(i)}
              onMouseLeave={() => setHover(null)}
              onFocus={() => setHover(i)}
              onBlur={() => setHover(null)}
              aria-label={`${d.label}: ${d.value} ${unitLabel}`}
            >
              <span
                className={cn('block w-full rounded-t-[4px] transition-opacity', hover !== null && hover !== i ? 'opacity-45' : 'opacity-100')}
                style={{ height: d.value ? `${Math.max(3, (d.value / max) * 100)}%` : 0, background: d.color ?? 'rgb(var(--c-accent))' }}
              />
            </button>
          ))}
        </div>
        {active && (
          <div
            role="status"
            className="pointer-events-none absolute -top-2 z-10 -translate-x-1/2 -translate-y-full whitespace-nowrap rounded border border-line-strong bg-elevated px-2.5 py-1.5 text-xs shadow-tooltip"
            style={{ left: `${((hover! + 0.5) / data.length) * 100}%` }}
          >
            <span className="text-fg-2">{active.hint ?? active.label}</span>
            <span className="t-num ml-2 font-semibold text-fg">{active.value}</span>
          </div>
        )}
      </div>
      <div className="mt-1.5 flex gap-[2px]" aria-hidden>
        {data.map((d) => (
          <span key={d.key} className="t-num flex-1 text-center text-2xs text-fg-3">
            {d.label}
          </span>
        ))}
      </div>
      <table className="sr-only">
        <caption>{caption}</caption>
        <tbody>
          {data.map((d) => (
            <tr key={d.key}>
              <th scope="row">{d.hint ?? d.label}</th>
              <td>{d.value}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  );
}
