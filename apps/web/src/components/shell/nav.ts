import {
  BarChart3,
  CalendarDays,
  Castle,
  Compass,
  Gavel,
  Home,
  Settings,
  Shield,
  Swords,
  Trophy,
  Users,
  Skull,
  Flag,
  type LucideIcon,
} from 'lucide-react';
import type { Permission } from '@blazonguild/types';
import { guildHref } from '@/lib/game';

export interface NavItem {
  key: string;
  label: string;
  href: string;
  icon: LucideIcon;
  /** Phase in which the module ships, when not available yet. */
  soon?: string;
  match?: 'exact' | 'prefix';
}

export interface GuildContext {
  region: string;
  slug: string;
  name: string;
  faction: 'ALLIANCE' | 'HORDE';
  crest: import('@blazonguild/types').GuildCrestDTO | null;
  permissions: Permission[];
}

export function guildNav(g: GuildContext): NavItem[] {
  const h = (sub = '') => guildHref(g.region, g.slug, sub);
  const items: NavItem[] = [
    { key: 'overview', label: 'Resumen', href: h(), icon: Home, match: 'exact' },
    { key: 'guild', label: 'La hermandad', href: h('/roster'), icon: Users },
    { key: 'armory', label: 'Armería', href: h('/roster?view=directory'), icon: Shield },
    { key: 'raids', label: 'Raids', href: h('/raids'), icon: Swords },
    { key: 'dungeons', label: 'Mazmorras', href: h('/dungeons'), icon: Castle },
    { key: 'pvp', label: 'JcJ', href: h('/pvp'), icon: Flag },
    { key: 'pve', label: 'JcE', href: h('/pve'), icon: Skull },
    { key: 'analytics', label: 'Analítica', href: h('/analytics'), icon: BarChart3, soon: 'Fase 5' },
    { key: 'rankings', label: 'Rankings', href: h('/rankings'), icon: Trophy },
    { key: 'events', label: 'Calendario', href: h('/events'), icon: CalendarDays },
  ];
  if (g.permissions.includes('audit.view') || g.permissions.includes('guild.settings') || g.permissions.includes('members.manage')) {
    items.push({ key: 'admin', label: 'Administración', href: h('/admin'), icon: Gavel });
  }
  return items;
}

export const globalNav: NavItem[] = [
  { key: 'explore', label: 'Explorar', href: '/', icon: Compass, match: 'exact' },
  { key: 'armory', label: 'Armería', href: '/armory', icon: Shield },
];

export const settingsItem: NavItem = { key: 'settings', label: 'Ajustes', href: '/settings', icon: Settings };

export function isActive(item: NavItem, pathname: string, search = '') {
  const [path, query] = item.href.split('?');
  const decoded = decodeURIComponent(pathname);
  const target = decodeURIComponent(path);
  if (query) return decoded === target && search.includes(query);
  if (item.match === 'exact') return decoded === target;
  return decoded === target || decoded.startsWith(target + '/');
}
