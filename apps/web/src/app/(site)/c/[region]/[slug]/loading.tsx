export default function Loading() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6" aria-busy="true" aria-label="Cargando">
      <div className="flex items-end gap-6">
        <div className="skeleton h-24 w-24 rounded-full" />
        <div className="flex-1 space-y-3">
          <div className="skeleton h-12 w-2/3 max-w-md" />
          <div className="skeleton h-4 w-1/2 max-w-sm" />
        </div>
      </div>
      <div className="mt-10 grid grid-cols-2 gap-4 sm:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="skeleton h-20" />
        ))}
      </div>
      <div className="mt-10 space-y-3">
        {[0, 1, 2, 3, 4, 5].map((i) => (
          <div key={i} className="skeleton h-10" />
        ))}
      </div>
      <p className="sr-only">Cargando datos de la hermandad desde Battle.net…</p>
    </div>
  );
}
