'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Search } from 'lucide-react';
import { guildHref } from '@/lib/game';
import { toSlug } from './SearchDialog';

/** Hero search: opens (and on first visit imports) any WoW: Forever guild by name. */
export function ExploreSearch() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [region, setRegion] = useState('eu');
  const [pending, setPending] = useState(false);
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (name.trim().length < 2) return;
        setPending(true);
        router.push(guildHref(region, toSlug(name)));
      }}
      className="flex flex-col gap-2 sm:flex-row"
      role="search"
    >
      <label className="sr-only" htmlFor="guild-name">
        Nombre de la hermandad
      </label>
      <div className="relative flex-1">
        <Search className="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-fg-3" aria-hidden />
        <input
          id="guild-name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Nombre de la hermandad"
          autoComplete="off"
          className="field h-14 pl-12 text-base"
          minLength={2}
          required
        />
      </div>
      <div className="flex gap-2">
        <label className="sr-only" htmlFor="guild-region">
          Región
        </label>
        <select id="guild-region" value={region} onChange={(e) => setRegion(e.target.value)} className="field h-14 w-24">
          <option value="eu">EU</option>
          <option value="us">US</option>
          <option value="kr">KR</option>
          <option value="tw">TW</option>
        </select>
        <button type="submit" className="btn-primary h-14 flex-1 px-6 sm:flex-none" disabled={pending}>
          {pending ? 'Buscando…' : 'Abrir'}
        </button>
      </div>
    </form>
  );
}
