'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { BadgeCheck, CircleDashed, RefreshCw, Save } from 'lucide-react';
import { GUILD_ROLE_LABEL, GUILD_ROLE_WEIGHT, type GuildRole } from '@blazonguild/types';
import { clientApi, ClientApiError } from '@/lib/client-api';
import { fmtDateTime, relativeTime } from '@/lib/format';
import { cn } from '@/lib/utils';

export interface AdminData {
  region: string;
  slug: string;
  viewerRole: GuildRole;
  permissions: { key: string; label: string; defaultRole: GuildRole; effectiveRole: GuildRole }[];
  ranks: { index: number; members: number; name: string | null; role: GuildRole | null }[];
  members: { userId: string; displayName: string; battleTag: string | null; role: GuildRole; verified: boolean; source: string; since: string }[];
  audit: { id: string; at: string; actor: string | null; action: string; entity: string; entityId: string; changes: unknown }[];
  sync: { state: string; lastSyncedAt: string | null; error: string | null };
  can: { settings: boolean; members: boolean; audit: boolean; sync: boolean };
  detailed: number;
  total: number;
}

const ASSIGNABLE: GuildRole[] = ['OFFICER', 'RAID_LEADER', 'RAIDER', 'MEMBER'];
const ALL_ROLES: GuildRole[] = ['GUILD_MASTER', 'OFFICER', 'RAID_LEADER', 'RAIDER', 'MEMBER', 'VISITOR'];

const ACTION_LABEL: Record<string, string> = {
  RAID_CREATE: 'Raid creada',
  RAID_UPDATE: 'Raid editada',
  RAID_COMPOSITION: 'Composición guardada',
  MEMBER_ROLE: 'Rol cambiado',
  GUILD_SETTINGS: 'Ajustes cambiados',
  GUILD_SYNC: 'Sincronización manual',
  ADMIN_LINK_CHARACTER: 'Personaje vinculado por un administrador',
};

type Tab = 'members' | 'ranks' | 'permissions' | 'audit' | 'sync';

function useSave() {
  const [state, setState] = useState<{ busy: boolean; msg: { ok: boolean; text: string } | null }>({ busy: false, msg: null });
  const run = async (fn: () => Promise<unknown>, ok: string) => {
    setState({ busy: true, msg: null });
    try {
      await fn();
      setState({ busy: false, msg: { ok: true, text: ok } });
      return true;
    } catch (err) {
      setState({ busy: false, msg: { ok: false, text: err instanceof ClientApiError ? err.message : 'No se pudo guardar' } });
      return false;
    }
  };
  return { ...state, run };
}

function Status({ msg }: { msg: { ok: boolean; text: string } | null }) {
  if (!msg) return null;
  return (
    <p role="status" className={cn('text-sm', msg.ok ? 'text-success' : 'text-danger')}>
      {msg.text}
    </p>
  );
}

export function AdminPanel({ data }: { data: AdminData }) {
  const router = useRouter();
  const base = `/v1/guilds/${data.region}/${encodeURIComponent(data.slug)}`;
  const members = [...data.members].sort((x, y) => GUILD_ROLE_WEIGHT[y.role] - GUILD_ROLE_WEIGHT[x.role] || x.displayName.localeCompare(y.displayName));
  const tabs: { key: Tab; label: string; show: boolean }[] = [
    { key: 'members', label: `Miembros (${data.members.length})`, show: true },
    { key: 'ranks', label: 'Rangos', show: data.can.settings },
    { key: 'permissions', label: 'Permisos', show: data.can.settings },
    { key: 'audit', label: 'Auditoría', show: data.can.audit },
    { key: 'sync', label: 'Sincronización', show: true },
  ];
  const [tab, setTab] = useState<Tab>('members');
  const save = useSave();

  // ── Members
  const [roles, setRoles] = useState<Record<string, GuildRole>>(Object.fromEntries(data.members.map((m) => [m.userId, m.role])));
  const canEdit = (current: GuildRole) => data.can.members && (data.viewerRole === 'GUILD_MASTER' || GUILD_ROLE_WEIGHT[data.viewerRole] > GUILD_ROLE_WEIGHT[current]);
  const assignable = ASSIGNABLE.filter((r) => data.viewerRole === 'GUILD_MASTER' || GUILD_ROLE_WEIGHT[data.viewerRole] > GUILD_ROLE_WEIGHT[r]);

  // ── Ranks
  const [rankNames, setRankNames] = useState<Record<string, string>>(Object.fromEntries(data.ranks.map((r) => [String(r.index), r.name ?? ''])));
  const [rankRoles, setRankRoles] = useState<Record<string, GuildRole>>(Object.fromEntries(data.ranks.filter((r) => r.index > 0).map((r) => [String(r.index), r.role ?? (r.index === 1 ? 'OFFICER' : 'MEMBER')])));

  // ── Permissions
  const [perms, setPerms] = useState<Record<string, GuildRole>>(Object.fromEntries(data.permissions.map((p) => [p.key, p.effectiveRole])));

  return (
    <div>
      <div role="tablist" aria-label="Secciones de administración" className="scrollbar-thin -mx-4 flex gap-1 overflow-x-auto border-b border-line px-4 sm:mx-0 sm:px-0">
        {tabs
          .filter((t) => t.show)
          .map((t) => (
            <button key={t.key} type="button" role="tab" aria-selected={tab === t.key} onClick={() => setTab(t.key)} className={cn('relative h-11 shrink-0 px-3 text-sm', tab === t.key ? 'text-fg' : 'text-fg-2 hover:text-fg')}>
              {t.label}
              {tab === t.key && <span aria-hidden className="absolute inset-x-2 -bottom-px h-0.5 bg-accent" />}
            </button>
          ))}
      </div>

      <div className="mt-6" role="tabpanel">
        {tab === 'members' && (
          <section aria-label="Miembros de la plataforma" className="space-y-3">
            <p className="max-w-prose text-sm text-fg-2">
              Cuentas de BlazonGuild con acceso a esta hermandad. Los roles marcados como <span className="text-success">verificados</span> salen del rango de su personaje en el juego y se actualizan solos en cada sincronización.
            </p>
            {data.members.length === 0 ? (
              <p className="text-sm text-fg-3">Nadie de la hermandad se ha unido todavía. Cuando entren con Battle.net aparecerán aquí.</p>
            ) : (
              <div className="frame-gold overflow-x-auto rounded-[4px]">
                <table className="w-full min-w-[640px] text-sm">
                  <thead className="surface-metal text-left text-xs text-fg-2">
                    <tr>
                      <th scope="col" className="px-4 py-2.5 font-medium">Miembro</th>
                      <th scope="col" className="px-3 py-2.5 font-medium">Origen</th>
                      <th scope="col" className="px-3 py-2.5 font-medium">Desde</th>
                      <th scope="col" className="px-3 py-2.5 font-medium">Rol</th>
                    </tr>
                  </thead>
                  <tbody>
                    {members.map((m) => (
                      <tr key={m.userId} className="border-t border-line/70">
                        <td className="px-4 py-2.5">
                          <span className="font-medium">{m.displayName}</span>
                          {m.battleTag && <span className="block text-xs text-fg-3">{m.battleTag}</span>}
                        </td>
                        <td className="px-3 py-2.5">
                          {m.verified ? (
                            <span className="inline-flex items-center gap-1 text-success"><BadgeCheck className="h-3.5 w-3.5" aria-hidden /> Battle.net</span>
                          ) : (
                            <span className="inline-flex items-center gap-1 text-warning"><CircleDashed className="h-3.5 w-3.5" aria-hidden /> Manual</span>
                          )}
                        </td>
                        <td className="px-3 py-2.5 text-fg-2">{relativeTime(m.since)}</td>
                        <td className="px-3 py-2.5">
                          {canEdit(m.role) ? (
                            <span className="flex items-center gap-2">
                              <label className="sr-only" htmlFor={`role-${m.userId}`}>Rol de {m.displayName}</label>
                              <select id={`role-${m.userId}`} className="field h-9 min-h-0 w-auto py-0" value={roles[m.userId]} onChange={(e) => setRoles((r) => ({ ...r, [m.userId]: e.target.value as GuildRole }))}>
                                {[...new Set([m.role, ...assignable])].map((r) => (
                                  <option key={r} value={r}>{GUILD_ROLE_LABEL[r]}</option>
                                ))}
                              </select>
                              {roles[m.userId] !== m.role && (
                                <button type="button" className="btn-primary h-9 min-h-0 px-3 text-xs" disabled={save.busy} onClick={async () => { if (await save.run(() => clientApi(`${base}/members/${m.userId}`, { method: 'PUT', body: { role: roles[m.userId] } }), `Rol de ${m.displayName} actualizado`)) router.refresh(); }}>
                                  Guardar
                                </button>
                              )}
                            </span>
                          ) : (
                            <span className="text-fg-2">{GUILD_ROLE_LABEL[m.role]}</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <Status msg={save.msg} />
          </section>
        )}

        {tab === 'ranks' && (
          <section aria-label="Rangos" className="space-y-4">
            <p className="max-w-prose text-sm text-fg-2">
              Battle.net solo publica el número de rango. Ponle el nombre que usáis en el juego y decide qué rol reciben en BlazonGuild los personajes <strong>verificados</strong> de cada rango. El rango 0 siempre es maestro.
            </p>
            <div className="frame-gold overflow-x-auto rounded-[4px]">
              <table className="w-full min-w-[560px] text-sm">
                <thead className="surface-metal text-left text-xs text-fg-2">
                  <tr>
                    <th scope="col" className="px-4 py-2.5 font-medium">Rango</th>
                    <th scope="col" className="px-3 py-2.5 font-medium">Personajes</th>
                    <th scope="col" className="px-3 py-2.5 font-medium">Nombre</th>
                    <th scope="col" className="px-3 py-2.5 font-medium">Rol al verificar</th>
                  </tr>
                </thead>
                <tbody>
                  {data.ranks.map((r) => (
                    <tr key={r.index} className="border-t border-line/70">
                      <td className="t-num px-4 py-2">{r.index}</td>
                      <td className="t-num px-3 py-2 text-fg-2">{r.members}</td>
                      <td className="px-3 py-2">
                        <label className="sr-only" htmlFor={`rank-${r.index}`}>Nombre del rango {r.index}</label>
                        <input id={`rank-${r.index}`} className="field h-9 min-h-0" maxLength={30} placeholder={r.index === 0 ? 'Maestro de la hermandad' : `Rango ${r.index}`} value={rankNames[String(r.index)] ?? ''} onChange={(e) => setRankNames((n) => ({ ...n, [String(r.index)]: e.target.value }))} />
                      </td>
                      <td className="px-3 py-2">
                        {r.index === 0 ? (
                          <span className="text-fg-2">{GUILD_ROLE_LABEL.GUILD_MASTER}</span>
                        ) : (
                          <>
                            <label className="sr-only" htmlFor={`rankrole-${r.index}`}>Rol del rango {r.index}</label>
                            <select id={`rankrole-${r.index}`} className="field h-9 min-h-0 w-auto py-0" value={rankRoles[String(r.index)]} onChange={(e) => setRankRoles((x) => ({ ...x, [String(r.index)]: e.target.value as GuildRole }))}>
                              {ASSIGNABLE.map((role) => (
                                <option key={role} value={role}>{GUILD_ROLE_LABEL[role]}</option>
                              ))}
                            </select>
                          </>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="flex items-center gap-3">
              <button
                type="button"
                className="btn-primary"
                disabled={save.busy}
                onClick={async () => {
                  const names = Object.fromEntries(Object.entries(rankNames).filter(([, v]) => v.trim()).map(([k, v]) => [k, v.trim()]));
                  if (await save.run(() => clientApi(`${base}/settings`, { method: 'PATCH', body: { rankNames: names, rankRoles } }), 'Rangos guardados; los roles verificados ya están actualizados')) router.refresh();
                }}
              >
                <Save className="h-4 w-4" aria-hidden /> Guardar rangos
              </button>
              <Status msg={save.msg} />
            </div>
          </section>
        )}

        {tab === 'permissions' && (
          <section aria-label="Permisos" className="space-y-4">
            <p className="max-w-prose text-sm text-fg-2">Rol mínimo para cada acción. Algunas acciones tienen un mínimo de seguridad que no se puede rebajar (por ejemplo, cambiar ajustes exige al menos oficial).</p>
            <ul className="frame-gold divide-y divide-line/70 rounded-[4px]">
              {data.permissions.map((p) => (
                <li key={p.key} className="flex flex-col gap-2 px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
                  <span>
                    <span className="text-sm">{p.label}</span>
                    <span className="block text-xs text-fg-3">Por defecto: {GUILD_ROLE_LABEL[p.defaultRole]}</span>
                  </span>
                  <label className="sr-only" htmlFor={`perm-${p.key}`}>Rol mínimo para {p.label}</label>
                  <select id={`perm-${p.key}`} className="field h-9 min-h-0 w-full py-0 sm:w-56" value={perms[p.key]} onChange={(e) => setPerms((x) => ({ ...x, [p.key]: e.target.value as GuildRole }))}>
                    {ALL_ROLES.map((r) => (
                      <option key={r} value={r}>{GUILD_ROLE_LABEL[r]}{r === 'VISITOR' ? ' (público)' : ''}</option>
                    ))}
                  </select>
                </li>
              ))}
            </ul>
            <div className="flex items-center gap-3">
              <button type="button" className="btn-primary" disabled={save.busy} onClick={async () => { if (await save.run(() => clientApi(`${base}/settings`, { method: 'PATCH', body: { permissions: perms } }), 'Permisos guardados')) router.refresh(); }}>
                <Save className="h-4 w-4" aria-hidden /> Guardar permisos
              </button>
              <Status msg={save.msg} />
            </div>
          </section>
        )}

        {tab === 'audit' && (
          <section aria-label="Registro de auditoría">
            {data.audit.length === 0 ? (
              <p className="text-sm text-fg-3">Todavía no hay acciones registradas en esta hermandad.</p>
            ) : (
              <ol className="frame-gold divide-y divide-line/70 rounded-[4px]">
                {data.audit.map((a) => (
                  <li key={a.id} className="grid gap-1 px-4 py-2.5 text-sm sm:grid-cols-[12rem_1fr_auto] sm:items-center">
                    <time dateTime={a.at} className="text-xs text-fg-3" title={fmtDateTime(a.at)}>{relativeTime(a.at)}</time>
                    <span>
                      <span className="font-medium">{ACTION_LABEL[a.action] ?? a.action}</span>
                      <span className="text-fg-3"> por {a.actor ?? 'el sistema'}</span>
                    </span>
                    <span className="text-xs text-fg-3">{a.entity}</span>
                  </li>
                ))}
              </ol>
            )}
          </section>
        )}

        {tab === 'sync' && (
          <section aria-label="Sincronización" className="max-w-xl space-y-4">
            <dl className="plate grid grid-cols-2 gap-4 rounded-[4px] p-5 text-sm">
              <div>
                <dt className="text-xs text-fg-3">Estado</dt>
                <dd className={data.sync.state === 'ERROR' ? 'text-danger' : 'text-success'}>{data.sync.state === 'OK' ? 'Correcta' : data.sync.state === 'PARTIAL' ? 'Parcial' : data.sync.state === 'RUNNING' ? 'En curso' : data.sync.state === 'ERROR' ? 'Con errores' : 'Pendiente'}</dd>
              </div>
              <div>
                <dt className="text-xs text-fg-3">Última</dt>
                <dd>{relativeTime(data.sync.lastSyncedAt)}</dd>
              </div>
              <div className="col-span-2">
                <dt className="text-xs text-fg-3">Perfiles completos</dt>
                <dd className="t-num">{data.detailed} de {data.total} personajes</dd>
                <dd className="mt-1 text-xs text-fg-3">Las hermandades grandes se completan por lotes cada 10 minutos para no saturar Battle.net.</dd>
              </div>
              {data.sync.error && <p className="col-span-2 text-xs text-danger">{data.sync.error}</p>}
            </dl>
            {data.can.sync && (
              <div className="flex items-center gap-3">
                <button type="button" className="btn-secondary" disabled={save.busy} onClick={async () => { if (await save.run(() => clientApi(`${base}/sync`, { method: 'POST', body: {} }), 'Sincronización iniciada; tardará unos minutos')) router.refresh(); }}>
                  <RefreshCw className={cn('h-4 w-4', save.busy && 'animate-spin')} aria-hidden /> Sincronizar ahora
                </button>
                <Status msg={save.msg} />
              </div>
            )}
          </section>
        )}
      </div>
    </div>
  );
}
