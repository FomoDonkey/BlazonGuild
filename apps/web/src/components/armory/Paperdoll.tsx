'use client';

import Image from 'next/image';
import { useCallback, useEffect, useRef, useState } from 'react';
import { X } from 'lucide-react';
import type { EquippedItemDTO, SlotType } from '@blazonguild/types';
import { FiligreeCorner } from '@/components/art/Ornaments';
import { ItemIcon } from '@/components/game/bits';
import { classVar, EQUIPMENT_SLOTS, qualityVar } from '@/lib/game';
import { cn } from '@/lib/utils';
import { ItemTooltipBody } from './ItemTooltip';

interface Active {
  item: EquippedItemDTO;
  rect: DOMRect;
  side: 'left' | 'right' | 'bottom';
  pinned: boolean;
}

function Slot({
  slot,
  item,
  side,
  onShow,
  onHide,
  onPin,
}: {
  slot: (typeof EQUIPMENT_SLOTS)[number];
  item: EquippedItemDTO | undefined;
  side: 'left' | 'right' | 'bottom';
  onShow: (item: EquippedItemDTO, el: HTMLElement, side: Active['side']) => void;
  onHide: () => void;
  onPin: (item: EquippedItemDTO, el: HTMLElement, side: Active['side']) => void;
}) {
  const mirrored = side === 'right';
  if (!item) {
    return (
      <div className={cn('flex items-center gap-3', mirrored && 'flex-row-reverse text-right', side === 'bottom' && 'flex-col gap-1 text-center')}>
        <span className="grid h-11 w-11 shrink-0 place-items-center rounded border border-dashed border-line-strong/50 bg-sunken/60" aria-hidden />
        <span className="hidden text-xs text-fg-3 lg:block">{slot.nameEs}</span>
        <span className="sr-only">{slot.nameEs}: vacío</span>
      </div>
    );
  }
  return (
    <button
      type="button"
      className={cn('group flex w-full min-w-0 items-center gap-3 rounded bg-black/30 p-1 pr-2 text-left ring-1 ring-white/5 backdrop-blur-[2px] transition-colors hover:bg-black/45 hover:ring-white/15', mirrored && 'flex-row-reverse text-right', side === 'bottom' && 'w-auto flex-col gap-1 text-center')}
      onMouseEnter={(e) => onShow(item, e.currentTarget, side)}
      onMouseLeave={onHide}
      onFocus={(e) => onShow(item, e.currentTarget, side)}
      onBlur={onHide}
      onClick={(e) => onPin(item, e.currentTarget, side)}
      aria-label={`${slot.nameEs}: ${item.name}${item.itemLevel ? `, nivel de objeto ${item.itemLevel}` : ''}`}
    >
      <ItemIcon src={item.iconUrl} quality={item.quality} size={44} className="transition-transform group-hover:scale-105" />
      <span className={cn('hidden min-w-0 flex-1 lg:block', side === 'bottom' && 'w-[9rem] flex-none')}>
        <span className="block truncate text-sm font-medium leading-tight" style={{ color: qualityVar(item.quality) }}>
          {item.name}
        </span>
        <span className="t-num block text-xs text-fg-3">
          {item.itemLevel !== null ? `iLvl ${item.itemLevel}` : slot.nameEs}
          {item.enchantments.length > 0 && <span className="text-success">, encantado</span>}
        </span>
      </span>
    </button>
  );
}

export function Paperdoll({ equipment, renderUrl, classId, name }: { equipment: EquippedItemDTO[]; renderUrl: string | null; classId: number; name: string }) {
  const bySlot = new Map<SlotType, EquippedItemDTO>(equipment.map((e) => [e.slot, e]));
  const [active, setActive] = useState<Active | null>(null);
  const [coarse, setCoarse] = useState(false);
  const tipRef = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState<{ left: number; top: number } | null>(null);

  useEffect(() => {
    const mq = window.matchMedia('(pointer: coarse)');
    setCoarse(mq.matches);
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setActive(null);
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  // Position the floating tooltip next to the slot, clamped to the viewport.
  useEffect(() => {
    if (!active || coarse || !tipRef.current) return setPos(null);
    const tip = tipRef.current.getBoundingClientRect();
    const r = active.rect;
    const gap = 12;
    let left = active.side === 'left' ? r.right + gap : active.side === 'right' ? r.left - tip.width - gap : r.left + r.width / 2 - tip.width / 2;
    let top = active.side === 'bottom' ? r.top - tip.height - gap : r.top;
    left = Math.max(8, Math.min(left, window.innerWidth - tip.width - 8));
    top = Math.max(64, Math.min(top, window.innerHeight - tip.height - 8));
    setPos({ left, top });
  }, [active, coarse]);

  const show = useCallback((item: EquippedItemDTO, el: HTMLElement, side: Active['side']) => {
    setActive((a) => (a?.pinned ? a : { item, rect: el.getBoundingClientRect(), side, pinned: false }));
  }, []);
  const hide = useCallback(() => setActive((a) => (a?.pinned ? a : null)), []);
  const pin = useCallback((item: EquippedItemDTO, el: HTMLElement, side: Active['side']) => {
    setActive((a) => (a?.pinned && a.item.slot === item.slot ? null : { item, rect: el.getBoundingClientRect(), side, pinned: true }));
  }, []);

  const left = EQUIPMENT_SLOTS.filter((s) => s.column === 'left');
  const right = EQUIPMENT_SLOTS.filter((s) => s.column === 'right');
  const bottom = EQUIPMENT_SLOTS.filter((s) => s.column === 'bottom');
  const glow = classVar(classId);

  return (
    <div className="relative">
      <div className="grid grid-cols-[auto_minmax(0,1fr)_auto] items-stretch gap-3 lg:grid-cols-[13.5rem_minmax(0,1fr)_13.5rem] lg:gap-5">
        <ul className="flex flex-col justify-between gap-2.5" aria-label="Equipo, columna izquierda">
          {left.map((s) => (
            <li key={s.type}>
              <Slot slot={s} item={bySlot.get(s.type)} side="left" onShow={show} onHide={hide} onPin={pin} />
            </li>
          ))}
        </ul>

        <div className="relative isolate min-h-[340px] sm:min-h-[440px] lg:min-h-[580px]">
          <div aria-hidden className="absolute inset-0 -z-10" style={{ background: `radial-gradient(55% 55% at 50% 45%, color-mix(in srgb, ${glow} 34%, transparent), transparent 72%)` }} />
          <div aria-hidden className="absolute inset-x-[10%] bottom-[4%] -z-10 h-[16%] rounded-[50%]" style={{ background: `radial-gradient(50% 50% at 50% 50%, color-mix(in srgb, ${glow} 28%, transparent), transparent 70%)` }} />
          <div aria-hidden className="absolute bottom-[9%] left-1/2 -z-10 h-[7%] w-[46%] -translate-x-1/2 rounded-[50%] bg-black/55 blur-md" />
          {renderUrl ? (
            <Image
              src={renderUrl}
              alt={`Render de ${name}`}
              fill
              priority
              sizes="(min-width: 1024px) 1400px, 160vw"
              className="pointer-events-none select-none object-cover"
              style={{ objectPosition: '50% 56%', transform: 'scale(1.55)', filter: `drop-shadow(0 0 22px color-mix(in srgb, ${glow} 45%, transparent))` }}
            />
          ) : (
            <p className="absolute inset-0 grid place-items-center px-6 text-center text-sm text-fg-3">Battle.net no ofrece render de este personaje.</p>
          )}
        </div>

        <ul className="flex flex-col justify-between gap-2.5" aria-label="Equipo, columna derecha">
          {right.map((s) => (
            <li key={s.type}>
              <Slot slot={s} item={bySlot.get(s.type)} side="right" onShow={show} onHide={hide} onPin={pin} />
            </li>
          ))}
        </ul>
      </div>
      <ul className="mt-4 flex justify-center gap-6 sm:gap-10" aria-label="Armas">
        {bottom.map((s) => (
          <li key={s.type}>
            <Slot slot={s} item={bySlot.get(s.type)} side="bottom" onShow={show} onHide={hide} onPin={pin} />
          </li>
        ))}
      </ul>

      {active && !coarse && (
        <div
          ref={tipRef}
          role="tooltip"
          className="pointer-events-auto fixed z-50 w-[300px] rounded-[4px] border border-[#c9a35a]/45 p-4 shadow-tooltip"
          style={{ left: pos?.left ?? -9999, top: pos?.top ?? 0, background: 'linear-gradient(180deg, rgb(12 16 34 / 0.97), rgb(6 8 18 / 0.98))' }}
        >
          <FiligreeCorner id="tt-a" size={26} className="pointer-events-none absolute -left-px -top-px" />
          <FiligreeCorner id="tt-b" size={26} className="pointer-events-none absolute -bottom-px -right-px -scale-100" />
          {active.pinned && (
            <button type="button" onClick={() => setActive(null)} className="absolute right-2 top-2 text-white/60 hover:text-white" aria-label="Cerrar">
              <X className="h-4 w-4" />
            </button>
          )}
          <ItemTooltipBody item={active.item} />
        </div>
      )}
      {active && coarse && (
        <div className="fixed inset-x-0 bottom-0 z-50 max-h-[70dvh] overflow-y-auto rounded-t-lg border-t border-white/15 p-4 pb-[calc(1rem+env(safe-area-inset-bottom))] shadow-tooltip" style={{ background: 'rgb(var(--tooltip-bg) / 0.98)' }} role="dialog" aria-label={active.item.name}>
          <button type="button" onClick={() => setActive(null)} className="absolute right-3 top-3 grid h-10 w-10 place-items-center text-white/70" aria-label="Cerrar">
            <X className="h-5 w-5" />
          </button>
          <ItemTooltipBody item={active.item} />
        </div>
      )}
    </div>
  );
}
