'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useId, useRef, useState } from 'react';
import { Loader2, Search, UserRound, Users } from 'lucide-react';
import type { SearchResultDTO } from '@blazonguild/types';
import { ClassIcon } from '@/components/game/bits';
import { GuildCrest } from '@/components/game/GuildCrest';
import { clientApi } from '@/lib/client-api';
import { characterHref, classVar, guildHref } from '@/lib/game';
import { cn } from '@/lib/utils';

/** WoW: Forever slugs: lower-case, spaces → hyphens ("C A Ñ A D A" → "c-a-ñ-a-d-a"). */
export const toSlug = (s: string) => s.trim().toLowerCase().replace(/\s+/g, '-');

interface Option {
  key: string;
  href: string;
  label: React.ReactNode;
  hint: string;
  icon: React.ReactNode;
}

export function SearchDialog({ open, onClose, defaultRegion }: { open: boolean; onClose: () => void; defaultRegion: string }) {
  const ref = useRef<HTMLDialogElement>(null);
  const router = useRouter();
  const listId = useId();
  const [q, setQ] = useState('');
  const [region, setRegion] = useState(defaultRegion);
  const [data, setData] = useState<SearchResultDTO | null>(null);
  const [loading, setLoading] = useState(false);
  const [cursor, setCursor] = useState(0);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  useEffect(() => {
    const term = q.trim();
    if (term.length < 2) {
      setData(null);
      return;
    }
    const ctrl = new AbortController();
    setLoading(true);
    const t = setTimeout(() => {
      clientApi<SearchResultDTO>(`/v1/search?q=${encodeURIComponent(term)}&region=${region}`, { signal: ctrl.signal })
        .then(setData)
        .catch(() => {})
        .finally(() => setLoading(false));
    }, 180);
    return () => {
      clearTimeout(t);
      ctrl.abort();
    };
  }, [q, region]);

  const term = q.trim();
  const options: Option[] = [];
  for (const g of data?.guilds ?? []) {
    options.push({ key: `g:${g.slug}`, href: guildHref(g.region, g.slug), label: g.name, hint: `Hermandad, ${g.memberCount} personajes`, icon: <GuildCrest crest={g.crest} name={g.name} size={28} /> });
  }
  for (const c of data?.characters ?? []) {
    options.push({
      key: `c:${c.slug}`,
      href: characterHref(c.region, c.slug),
      label: <span style={{ color: classVar(c.classId) }}>{c.displayName}</span>,
      hint: `Nivel ${c.level}${c.guildName ? `, ${c.guildName}` : ''}`,
      icon: <ClassIcon classId={c.classId} size={28} />,
    });
  }
  if (term.length >= 2) {
    const slug = toSlug(term);
    if (!data?.guilds.some((g) => g.slug === slug)) {
      options.push({ key: 'bnet-guild', href: guildHref(region, slug), label: <>Abrir la hermandad «{term}»</>, hint: 'Se importa desde Battle.net si existe', icon: <Users className="h-5 w-5 text-fg-3" aria-hidden /> });
    }
    if (slug.includes('-') && !data?.characters.some((c) => c.slug === slug)) {
      options.push({ key: 'bnet-char', href: characterHref(region, slug), label: <>Inspeccionar a «{term}»</>, hint: 'Personaje (nombre y apellido)', icon: <UserRound className="h-5 w-5 text-fg-3" aria-hidden /> });
    }
  }

  const go = (o: Option | undefined) => {
    if (!o) return;
    onClose();
    setQ('');
    router.push(o.href);
  };

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(e) => e.target === e.currentTarget && onClose()}
      className="mt-[10vh] w-[min(640px,calc(100vw-24px))] max-w-none rounded-lg border border-line-strong bg-surface p-0 text-fg shadow-tooltip backdrop:bg-black/60"
      aria-label="Buscar"
    >
      <div className="flex items-center gap-3 border-b border-line px-4">
        {loading ? <Loader2 className="h-5 w-5 animate-spin text-fg-3" aria-hidden /> : <Search className="h-5 w-5 text-fg-3" aria-hidden />}
        <input
          autoFocus
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setCursor(0);
          }}
          onKeyDown={(e) => {
            if (e.key === 'ArrowDown') {
              e.preventDefault();
              setCursor((c) => Math.min(c + 1, options.length - 1));
            } else if (e.key === 'ArrowUp') {
              e.preventDefault();
              setCursor((c) => Math.max(c - 1, 0));
            } else if (e.key === 'Enter') {
              e.preventDefault();
              go(options[cursor]);
            }
          }}
          placeholder="Nombre de hermandad o personaje (p. ej. el-peregrino)"
          className="h-14 min-w-0 flex-1 bg-transparent text-base text-fg placeholder:text-fg-3 focus:outline-none"
          role="combobox"
          aria-expanded={options.length > 0}
          aria-controls={listId}
          aria-activedescendant={options[cursor] ? `${listId}-${cursor}` : undefined}
          aria-label="Buscar hermandad o personaje"
        />
        <select value={region} onChange={(e) => setRegion(e.target.value)} className="h-9 rounded border border-line bg-sunken px-2 text-sm text-fg-2" aria-label="Región">
          <option value="eu">EU</option>
          <option value="us">US</option>
          <option value="kr">KR</option>
          <option value="tw">TW</option>
        </select>
      </div>
      <ul id={listId} role="listbox" className="max-h-[50vh] overflow-y-auto p-2">
        {options.map((o, i) => (
          <li
            key={o.key}
            id={`${listId}-${i}`}
            role="option"
            aria-selected={i === cursor}
            onMouseEnter={() => setCursor(i)}
            onClick={() => go(o)}
            className={cn('flex cursor-pointer items-center gap-3 rounded px-3 py-2.5', i === cursor ? 'bg-elevated' : 'hover:bg-elevated/60')}
          >
            <span className="grid w-8 place-items-center">{o.icon}</span>
            <span className="min-w-0">
              <span className="block truncate font-medium">{o.label}</span>
              <span className="block truncate text-xs text-fg-3">{o.hint}</span>
            </span>
          </li>
        ))}
        {term.length < 2 && (
          <li className="px-3 py-6 text-sm text-fg-2">
            Escribe al menos dos letras. Puedes abrir cualquier hermandad o personaje de World of Warcraft: Forever, aunque nadie lo haya añadido todavía.
          </li>
        )}
      </ul>
    </dialog>
  );
}
