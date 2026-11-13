'use client';

import { useState } from 'react';
import type { TalentLoadoutDTO, TalentNodeDTO, TalentTreeDTO } from '@blazonguild/types';
import { cn } from '@/lib/utils';

const CELL = 52; // px per grid cell (icon 40 + gutter)

function Node({ n, onShow, onHide, active }: { n: TalentNodeDTO; onShow: (n: TalentNodeDTO) => void; onHide: () => void; active: boolean }) {
  const learned = n.rank > 0;
  const maxed = n.rank >= n.maxRank;
  return (
    <button
      type="button"
      className="absolute grid h-10 w-10 place-items-center rounded focus-visible:z-20"
      style={{ left: (n.col - 1) * CELL + 6, top: (n.row - 1) * CELL + 6 }}
      onMouseEnter={() => onShow(n)}
      onMouseLeave={onHide}
      onFocus={() => onShow(n)}
      onBlur={onHide}
      onClick={() => onShow(n)}
      aria-label={`${n.name}, rango ${n.rank} de ${n.maxRank}`}
      aria-pressed={active}
    >
      <span
        className={cn('block h-10 w-10 overflow-hidden rounded ring-2 ring-offset-1 ring-offset-[rgb(var(--c-sunken))]', maxed ? 'ring-accent' : learned ? 'ring-success' : 'ring-line-strong/60')}
      >
        {n.iconUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={n.iconUrl} alt="" width={40} height={40} loading="lazy" className={cn('h-full w-full object-cover', !learned && 'opacity-45 grayscale')} />
        ) : (
          <span className="block h-full w-full bg-elevated" />
        )}
      </span>
      <span className={cn('t-num absolute -bottom-1.5 -right-1.5 rounded-sm px-1 text-[10px] font-bold leading-4', maxed ? 'bg-accent text-accent-on' : learned ? 'bg-success text-black' : 'bg-sunken text-fg-3 ring-1 ring-line-strong/60')}>
        {n.rank}/{n.maxRank}
      </span>
    </button>
  );
}

function Tree({ tree }: { tree: TalentTreeDTO }) {
  const [hover, setHover] = useState<TalentNodeDTO | null>(null);
  const width = tree.cols * CELL;
  const height = tree.rows * CELL;
  const byId = new Map(tree.nodes.map((n) => [n.id, n]));
  const center = (n: TalentNodeDTO) => ({ x: (n.col - 1) * CELL + 26, y: (n.row - 1) * CELL + 26 });
  return (
    <section aria-label={`Árbol ${tree.name}`} className="flex flex-col">
      <header className="mb-3 flex items-center gap-3">
        {tree.iconUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={tree.iconUrl} alt="" width={32} height={32} className="h-8 w-8 rounded ring-1 ring-line-strong" />
        )}
        <h3 className="t-display text-lg">{tree.name}</h3>
        <span className="t-num ml-auto text-lg font-semibold text-accent">{tree.spentPoints}</span>
      </header>
      <div className="plate relative mx-auto overflow-hidden rounded-[4px] p-2" style={{ width: width + 16 }}>
        {tree.iconUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={tree.iconUrl} alt="" aria-hidden className="pointer-events-none absolute inset-0 h-full w-full scale-150 object-cover opacity-[0.10] blur-[6px]" />
        )}
        <div className="relative" style={{ width, height }}>
          <svg className="pointer-events-none absolute inset-0" width={width} height={height} aria-hidden>
            {tree.nodes.flatMap((n) =>
              n.lockedBy.map((pid) => {
                const p = byId.get(pid);
                if (!p) return null;
                const a = center(p);
                const b = center(n);
                const on = p.rank > 0 && n.rank > 0;
                return <line key={`${pid}-${n.id}`} x1={a.x} y1={a.y + 20} x2={b.x} y2={b.y - 20} stroke={on ? 'rgb(var(--c-accent))' : 'rgb(var(--c-line-strong))'} strokeWidth={on ? 3 : 2} strokeLinecap="round" />;
              }),
            )}
          </svg>
          {tree.nodes.map((n) => (
            <Node key={n.id} n={n} onShow={setHover} onHide={() => setHover(null)} active={hover?.id === n.id} />
          ))}
        </div>
      </div>
      <div className="plate mt-3 min-h-[5.5rem] rounded-[4px] p-3 text-sm" aria-live="polite">
        {hover ? (
          <>
            <p className="font-semibold">
              {hover.name} <span className="t-num font-normal text-fg-3">rango {hover.rank}/{hover.maxRank}</span>
            </p>
            <p className="mt-1 text-fg-2">{hover.description}</p>
          </>
        ) : (
          <p className="text-fg-3">Pasa el ratón o enfoca un talento para leer su efecto.</p>
        )}
      </div>
    </section>
  );
}

export function TalentTrees({ loadout }: { loadout: TalentLoadoutDTO }) {
  const dominant = loadout.trees.reduce((best, t, i, all) => (t.spentPoints > all[best].spentPoints ? i : best), 0);
  const [tab, setTab] = useState(dominant);
  return (
    <div>
      <div role="tablist" aria-label="Árboles de talentos" className="mb-4 flex gap-1 rounded border border-line bg-sunken p-1 xl:hidden">
        {loadout.trees.map((t, i) => (
          <button key={t.specId} type="button" role="tab" aria-selected={tab === i} onClick={() => setTab(i)} className={cn('flex min-h-[40px] flex-1 items-center justify-center gap-2 rounded-sm text-sm', tab === i ? 'bg-elevated text-fg' : 'text-fg-2')}>
            {t.name}
            <span className="t-num text-accent">{t.spentPoints}</span>
          </button>
        ))}
      </div>
      <div className="xl:hidden">
        <Tree tree={loadout.trees[tab]} />
      </div>
      <div className="hidden gap-8 xl:grid xl:grid-cols-3">
        {loadout.trees.map((t) => (
          <Tree key={t.specId} tree={t} />
        ))}
      </div>
    </div>
  );
}
