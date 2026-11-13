import { notFound } from 'next/navigation';
import { isRegion } from '@blazonguild/types';
import { Shell } from '@/components/shell/Shell';
import { ErrorPanel } from '@/components/ui/states';
import { ApiFailure, getGuildOverview, getMe } from '@/lib/api';

export default async function GuildLayout({ children, params }: { children: React.ReactNode; params: Promise<{ region: string; slug: string }> }) {
  const { region, slug } = await params;
  if (!isRegion(region)) notFound();
  const me = await getMe();
  try {
    const overview = await getGuildOverview(region, slug);
    const g = overview.guild;
    return (
      <Shell me={me} guild={{ region: g.region, slug: g.slug, name: g.name, faction: g.faction, crest: g.crest, permissions: overview.viewer.permissions }}>
        {children}
      </Shell>
    );
  } catch (err) {
    if (err instanceof ApiFailure && err.status === 404) notFound();
    const message = err instanceof ApiFailure ? err.message : 'Error inesperado al cargar la hermandad.';
    return (
      <Shell me={me} guild={null}>
        <div className="mx-auto max-w-3xl px-4 py-16 sm:px-6">
          <ErrorPanel title="No hemos podido cargar esta hermandad" message={message} />
        </div>
      </Shell>
    );
  }
}
