import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { BadgeCheck, CircleDashed, FlaskConical, Sigma } from 'lucide-react';
import { getGuildOverview } from '@/lib/api';
import { guildHref } from '@/lib/game';

type Props = { params: Promise<{ region: string; slug: string; section: string }> };

/**
 * Modules scheduled for later phases. Each page states honestly what it will contain and
 * which data source makes it possible — no placeholder dashboards with invented numbers.
 */
const SECTIONS: Record<string, { title: string; phase: string; lead: string; items: { label: string; source: 'api' | 'addon' | 'log' | 'manual' }[] }> = {
  dungeons: {
    title: 'Mazmorras',
    phase: 'Fase 4',
    lead: 'Directorio de mazmorras con jefes y botín, buscador de grupo para tanques, sanadores y daño, y el historial de partidas de la hermandad.',
    items: [
      { label: 'Ficha de cada mazmorra: nivel recomendado, jefes y botín destacado', source: 'api' },
      { label: 'Buscador de grupo por rol, nivel y disponibilidad', source: 'manual' },
      { label: 'Historial de partidas y tiempos', source: 'addon' },
    ],
  },
  pvp: {
    title: 'JcJ',
    phase: 'Fase 4',
    lead: 'Actividad competitiva con lo que WoW: Forever expone de verdad: muertes con honor y rango de honor por personaje, comparativas y evolución en el tiempo.',
    items: [
      { label: 'Muertes con honor y rango de honor (ya se sincronizan)', source: 'api' },
      { label: 'Evolución semanal a partir de las capturas', source: 'api' },
      { label: 'Victorias y derrotas en campos de batalla', source: 'addon' },
    ],
  },
  pve: {
    title: 'JcE',
    phase: 'Fase 4',
    lead: 'Progreso de banda jefe a jefe, primeras muertes de la hermandad, intentos y composición de cada encuentro.',
    items: [
      { label: 'Encuentros de banda por personaje (cuando Battle.net los publique para Forever)', source: 'api' },
      { label: 'Intentos, muertes y duración de cada encuentro', source: 'log' },
      { label: 'Primeras muertes y cronología de la hermandad', source: 'log' },
    ],
  },
  analytics: {
    title: 'Analítica',
    phase: 'Fase 5',
    lead: 'Motor de analítica sobre registros de combate: DPS, HPS, daño recibido, supervivencia y asistencia, con fórmulas documentadas y tamaño de muestra en cada gráfica.',
    items: [
      { label: 'Procesado de WoWCombatLog.txt subido desde la app compañera', source: 'log' },
      { label: 'Series temporales de 7, 30 y 90 días e historial completo', source: 'log' },
      { label: 'Distribución de niveles, equipo y talentos por clase (ya disponible en Resumen y Rankings)', source: 'api' },
    ],
  },
  events: {
    title: 'Eventos',
    phase: 'Fase 4',
    lead: 'Calendario mensual, semanal y agenda de la hermandad, con recordatorios y registro de asistencia. Las raids ya funcionan en su propia sección.',
    items: [
      { label: 'Calendario y agenda cómoda en el móvil', source: 'manual' },
      { label: 'Recordatorios por notificación (y Discord, opcional)', source: 'manual' },
      { label: 'Asistencia real confirmada por el addon', source: 'addon' },
    ],
  },
  admin: {
    title: 'Administración',
    phase: 'Fase 4',
    lead: 'Gestión de miembros y roles, nombres de rango, permisos por hermandad, revisión de sincronizaciones y registro de auditoría. La API ya lo soporta; falta la interfaz.',
    items: [
      { label: 'Miembros de la plataforma y asignación de roles (auditada)', source: 'manual' },
      { label: 'Nombres de rango y rol por rango para personajes verificados', source: 'manual' },
      { label: 'Registro de auditoría y estado de sincronización', source: 'api' },
    ],
  },
};

const SOURCE = {
  api: { label: 'API Battle.net', icon: BadgeCheck },
  addon: { label: 'Addon + app compañera', icon: FlaskConical },
  log: { label: 'Registro de combate', icon: Sigma },
  manual: { label: 'Introducido por miembros', icon: CircleDashed },
} as const;

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { section } = await params;
  return { title: SECTIONS[section]?.title ?? 'Sección' };
}

export default async function SectionPage({ params }: Props) {
  const { region, slug, section } = await params;
  const def = SECTIONS[section];
  if (!def) notFound();
  const o = await getGuildOverview(region, slug);
  return (
    <div className="mx-auto max-w-3xl px-4 py-10 sm:px-6">
      <p className="text-sm text-accent">{def.phase} del plan de desarrollo</p>
      <h1 className="t-display mt-1 text-3xl sm:text-4xl">{def.title}</h1>
      <p className="mt-3 max-w-prose text-fg-2">{def.lead}</p>
      <h2 className="mt-8 text-sm font-medium text-fg">Qué incluirá y de dónde saldrán los datos</h2>
      <ul className="mt-3 divide-y divide-line border-y border-line">
        {def.items.map((it) => {
          const S = SOURCE[it.source];
          return (
            <li key={it.label} className="flex flex-col gap-1 py-3 sm:flex-row sm:items-center sm:justify-between">
              <span className="text-sm">{it.label}</span>
              <span className="flex shrink-0 items-center gap-1.5 text-xs text-fg-3">
                <S.icon className="h-3.5 w-3.5" aria-hidden /> {S.label}
              </span>
            </li>
          );
        })}
      </ul>
      <p className="mt-6 text-sm text-fg-2">
        Mientras tanto, consulta el <Link href={guildHref(region, slug)} className="link">resumen de {o.guild.name}</Link>, su <Link href={guildHref(region, slug, '/roster')} className="link">roster</Link> o los{' '}
        <Link href={guildHref(region, slug, '/rankings')} className="link">rankings</Link>.
      </p>
    </div>
  );
}
