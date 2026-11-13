import type { Metadata } from 'next';
import Link from 'next/link';
import { ArmorySearch } from '@/components/armory/ArmorySearch';
import { getMe } from '@/lib/api';
import { characterHref, classVar } from '@/lib/game';

export const metadata: Metadata = { title: 'Armería' };

export default async function ArmoryIndexPage() {
  const me = await getMe();
  return (
    <div className="mx-auto max-w-3xl px-4 py-12 sm:px-6 sm:py-16">
      <h1 className="t-display text-4xl sm:text-5xl">Armería</h1>
      <p className="mt-3 max-w-prose text-fg-2">
        Inspecciona cualquier personaje de World of Warcraft: Forever: equipo pieza a pieza, atributos, los tres árboles de talentos, profesiones e historial. Escribe su nombre y apellido.
      </p>
      <div className="mt-8">
        <ArmorySearch />
      </div>
      {me && me.characters.length > 0 && (
        <section aria-labelledby="mine" className="mt-12">
          <h2 id="mine" className="t-display text-xl">
            Tus personajes
          </h2>
          <ul className="mt-3 divide-y divide-line border-y border-line">
            {me.characters.map((c) => (
              <li key={c.id}>
                <Link href={characterHref(c.region, c.slug)} className="flex items-center justify-between py-3 hover:bg-elevated/30">
                  <span className="font-semibold" style={{ color: classVar(c.classId) }}>
                    {c.displayName}
                  </span>
                  <span className="t-num text-sm text-fg-3">nivel {c.level}</span>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
