import Link from 'next/link';

export default function NotFound() {
  return (
    <div className="mx-auto grid min-h-[60vh] max-w-xl place-content-center px-4 text-center">
      <p className="t-figure text-6xl text-accent">404</p>
      <h1 className="t-display mt-2 text-2xl">No hemos encontrado esto en Azeroth</h1>
      <p className="mt-3 text-fg-2">
        La hermandad o el personaje no existe en Battle.net, o su perfil no es público. Comprueba la región y la ortografía: en WoW: Forever los personajes llevan nombre y apellido.
      </p>
      <div className="mt-6 flex justify-center gap-3">
        <Link href="/" className="btn-primary">
          Buscar hermandad
        </Link>
        <Link href="/armory" className="btn-secondary">
          Buscar personaje
        </Link>
      </div>
    </div>
  );
}
