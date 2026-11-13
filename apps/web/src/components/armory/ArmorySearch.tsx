'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { characterHref } from '@/lib/game';
import { toSlug } from '@/components/shell/SearchDialog';

export function ArmorySearch() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [region, setRegion] = useState('eu');
  const [hint, setHint] = useState<string | null>(null);
  return (
    <form
      role="search"
      className="space-y-2"
      onSubmit={(e) => {
        e.preventDefault();
        const slug = toSlug(name);
        if (!slug.includes('-')) {
          setHint('En WoW: Forever los personajes tienen nombre y apellido, por ejemplo «El Peregrino».');
          return;
        }
        router.push(characterHref(region, slug));
      }}
    >
      <div className="flex flex-col gap-2 sm:flex-row">
        <label htmlFor="char-name" className="sr-only">
          Nombre y apellido del personaje
        </label>
        <input id="char-name" value={name} onChange={(e) => { setName(e.target.value); setHint(null); }} placeholder="Nombre y apellido" className="field h-12 flex-1 text-base" autoComplete="off" aria-describedby="char-hint" />
        <label htmlFor="char-region" className="sr-only">
          Región
        </label>
        <select id="char-region" value={region} onChange={(e) => setRegion(e.target.value)} className="field h-12 w-24">
          <option value="eu">EU</option>
          <option value="us">US</option>
          <option value="kr">KR</option>
          <option value="tw">TW</option>
        </select>
        <button type="submit" className="btn-primary h-12 px-6">
          Inspeccionar
        </button>
      </div>
      <p id="char-hint" className={hint ? 'text-sm text-warning' : 'text-xs text-fg-3'}>
        {hint ?? 'Si nadie lo ha consultado antes, se importa al momento desde Battle.net.'}
      </p>
    </form>
  );
}
