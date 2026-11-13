'use client';

import { useState } from 'react';
import { iconUrl } from '@blazonguild/types';
import { qualityVar } from '@/lib/game';
import { cn } from '@/lib/utils';

/** INV_Misc_QuestionMark — the in-game placeholder for unknown icons. */
const FALLBACK = iconUrl(134400);

export function ItemIcon({ src, quality, size = 40, className, alt = '' }: { src: string | null; quality: string; size?: number; className?: string; alt?: string }) {
  const [failed, setFailed] = useState(false);
  const url = !src || failed ? FALLBACK : src;
  return (
    <span
      className={cn('relative inline-block shrink-0 overflow-hidden rounded bg-sunken', className)}
      style={{ width: size, height: size, boxShadow: `inset 0 0 0 1px ${qualityVar(quality)}, 0 0 0 1px rgb(0 0 0 / 0.6)${['RARE', 'EPIC', 'LEGENDARY', 'ARTIFACT', 'HEIRLOOM'].includes(quality) ? `, 0 0 14px -3px ${qualityVar(quality)}` : ''}` }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={url} alt={alt} width={size} height={size} loading="lazy" onError={() => setFailed(true)} className="h-full w-full scale-[1.08] object-cover" />
    </span>
  );
}
