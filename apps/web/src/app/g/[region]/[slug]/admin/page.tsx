import type { Metadata } from 'next';
import { Lock } from 'lucide-react';
import type { GuildRole, ViewerContextDTO } from '@blazonguild/types';
import { PageBanner } from '@/components/art/CinematicHero';
import { factionAtmosphere } from '@/components/art/raid-art';
import { AdminPanel, type AdminData } from '@/components/admin/AdminPanel';
import { GuildCrest } from '@/components/game/GuildCrest';
import { EmptyState } from '@/components/ui/states';
import { api, ApiFailure, getGuildOverview, guildPath } from '@/lib/api';

type Props = { params: Promise<{ region: string; slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { region, slug } = await params;
  const o = await getGuildOverview(region, slug).catch(() => null);
  return { title: o ? `Administración de ${o.guild.name}` : 'Administración' };
}

interface SettingsResponse {
  viewer: ViewerContextDTO;
  settings: { rankNames?: Record<string, string>; rankRoles?: Record<string, GuildRole>; permissions?: Record<string, GuildRole> };
  ranks: AdminData['ranks'];
  permissions: AdminData['permissions'];
  sync: AdminData['sync'];
}

export default async function AdminPage({ params }: Props) {
  const { region, slug } = await params;
  const overview = await getGuildOverview(region, slug);
  const atmo = factionAtmosphere(overview.guild.faction);
  const base = guildPath(region, slug);
  const banner = (
    <PageBanner art={atmo.art} hue={atmo.hue} glow={atmo.glow} crest={<GuildCrest crest={overview.guild.crest} name={overview.guild.name} size={64} />} title="Administración" subtitle={<>Miembros, rangos, permisos y auditoría de {overview.guild.name}</>} />
  );

  let settings: SettingsResponse;
  try {
    settings = await api<SettingsResponse>(`${base}/settings`);
  } catch (err) {
    if (err instanceof ApiFailure && (err.status === 401 || err.status === 403)) {
      return (
        <div>
          {banner}
          <div className="mx-auto max-w-2xl px-4 py-10 sm:px-6">
            <EmptyState icon={Lock} title="Solo para el liderazgo de la hermandad" action={err.status === 401 ? { href: '/login', label: 'Entrar' } : undefined}>
              La administración está disponible para oficiales y para el maestro de la hermandad. Con Battle.net, el rol se asigna solo según tu rango en el juego.
            </EmptyState>
          </div>
        </div>
      );
    }
    throw err;
  }
  const can = (p: string) => settings.viewer.permissions.includes(p as never);
  const [members, audit] = await Promise.all([
    can('members.view') ? api<{ members: AdminData['members'] }>(`${base}/members`).then((r) => r.members) : Promise.resolve([]),
    can('audit.view') ? api<{ items: AdminData['audit']; total: number }>(`${base}/audit`).then((r) => r.items) : Promise.resolve([]),
  ]);

  const data: AdminData = {
    region,
    slug,
    viewerRole: settings.viewer.role,
    permissions: settings.permissions,
    ranks: settings.ranks,
    members,
    audit,
    sync: settings.sync,
    can: { settings: can('guild.settings'), members: can('members.manage'), audit: can('audit.view'), sync: can('guild.sync') },
    detailed: overview.stats.detailedMembers,
    total: overview.stats.members,
  };

  return (
    <div>
      {banner}
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6">
        <AdminPanel data={data} />
      </div>
    </div>
  );
}
