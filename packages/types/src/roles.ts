/**
 * Role-based access control shared by BlazonGuild Core and the web platform.
 *
 * Two layers:
 *  - Platform role (per user account): ADMIN or USER.
 *  - Guild role (per user *per guild*): GUILD_MASTER > OFFICER > RAID_LEADER > RAIDER > MEMBER.
 *    Anyone without a membership in a guild is a VISITOR of that guild.
 *
 * Each guild can override the minimum role of any permission (stored in guild settings),
 * which makes permissions granular and configurable without code changes.
 */

export const GUILD_ROLES = ['GUILD_MASTER', 'OFFICER', 'RAID_LEADER', 'RAIDER', 'MEMBER', 'VISITOR'] as const;
export type GuildRole = (typeof GUILD_ROLES)[number];
export type PlatformRole = 'ADMIN' | 'USER';

/** Higher number = more authority. */
export const GUILD_ROLE_WEIGHT: Record<GuildRole, number> = {
  GUILD_MASTER: 50,
  OFFICER: 40,
  RAID_LEADER: 30,
  RAIDER: 20,
  MEMBER: 10,
  VISITOR: 0,
};

export const GUILD_ROLE_LABEL: Record<GuildRole, string> = {
  GUILD_MASTER: 'Maestro de hermandad',
  OFFICER: 'Oficial',
  RAID_LEADER: 'Líder de banda',
  RAIDER: 'Raider',
  MEMBER: 'Miembro',
  VISITOR: 'Visitante',
};

export const PERMISSIONS = {
  'guild.view': 'Ver la página pública de la hermandad',
  'guild.sync': 'Forzar sincronización con Battle.net',
  'guild.settings': 'Editar ajustes, nombres de rango y permisos',
  'members.view': 'Ver miembros verificados de la plataforma',
  'members.manage': 'Cambiar roles de la plataforma',
  'raids.view': 'Ver raids y convocatorias',
  'raids.signup': 'Inscribirse en raids',
  'raids.create': 'Crear y editar raids',
  'raids.manage': 'Gestionar composición y asistencia',
  'audit.view': 'Consultar el registro de auditoría',
} as const;
export type Permission = keyof typeof PERMISSIONS;

export const DEFAULT_PERMISSION_MIN_ROLE: Record<Permission, GuildRole> = {
  'guild.view': 'VISITOR',
  'guild.sync': 'OFFICER',
  'guild.settings': 'GUILD_MASTER',
  'members.view': 'MEMBER',
  'members.manage': 'OFFICER',
  'raids.view': 'MEMBER',
  'raids.signup': 'MEMBER',
  'raids.create': 'RAID_LEADER',
  'raids.manage': 'RAID_LEADER',
  'audit.view': 'OFFICER',
};

/** Permissions that can never be lowered below these roles, whatever a guild configures. */
const HARD_FLOOR: Partial<Record<Permission, GuildRole>> = {
  'guild.settings': 'OFFICER',
  'members.manage': 'OFFICER',
  'audit.view': 'RAID_LEADER',
};

export type PermissionOverrides = Partial<Record<Permission, GuildRole>>;

export function minRoleFor(permission: Permission, overrides?: PermissionOverrides | null): GuildRole {
  const configured = overrides?.[permission] ?? DEFAULT_PERMISSION_MIN_ROLE[permission];
  const floor = HARD_FLOOR[permission];
  if (floor && GUILD_ROLE_WEIGHT[configured] < GUILD_ROLE_WEIGHT[floor]) return floor;
  return configured;
}

export function hasGuildPermission(
  role: GuildRole,
  permission: Permission,
  opts?: { overrides?: PermissionOverrides | null; platformRole?: PlatformRole },
): boolean {
  if (opts?.platformRole === 'ADMIN') return true;
  return GUILD_ROLE_WEIGHT[role] >= GUILD_ROLE_WEIGHT[minRoleFor(permission, opts?.overrides)];
}

/** Whether `actor` may assign `target` role to someone currently holding `current`. */
export function canAssignRole(actor: GuildRole, current: GuildRole, target: GuildRole, platformRole?: PlatformRole) {
  if (platformRole === 'ADMIN') return true;
  const a = GUILD_ROLE_WEIGHT[actor];
  // Nobody below GM can touch someone of equal or higher rank, nor promote to their own level.
  return a > GUILD_ROLE_WEIGHT[current] && a > GUILD_ROLE_WEIGHT[target];
}

/** Default mapping from in-game guild rank index (0 = GM) to platform role, for verified characters. */
export function defaultRoleForRankIndex(rankIndex: number): GuildRole {
  if (rankIndex === 0) return 'GUILD_MASTER';
  if (rankIndex === 1) return 'OFFICER';
  return 'MEMBER';
}
