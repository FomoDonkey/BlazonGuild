'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Bell, LogIn, LogOut, Monitor, Moon, Settings, Sun } from 'lucide-react';
import type { MeDTO } from '@blazonguild/types';
import { clientApi } from '@/lib/client-api';
import { characterHref, classVar } from '@/lib/game';
import { relativeTime } from '@/lib/format';
import { cn } from '@/lib/utils';

function useDisclosure() {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false);
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);
  return { open, setOpen, ref };
}

export type ThemeChoice = 'system' | 'dark' | 'light';

export function applyTheme(choice: ThemeChoice) {
  try {
    if (choice === 'system') localStorage.removeItem('forever-theme');
    else localStorage.setItem('forever-theme', choice);
  } catch {
    /* storage unavailable */
  }
  const resolved = choice === 'system' ? (window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark') : choice;
  document.documentElement.dataset.theme = resolved;
}

export function ThemeSwitch({ className }: { className?: string }) {
  const [choice, setChoice] = useState<ThemeChoice>('system');
  useEffect(() => {
    try {
      const t = localStorage.getItem('forever-theme');
      setChoice(t === 'dark' || t === 'light' ? t : 'system');
    } catch {
      /* ignore */
    }
  }, []);
  const options: { value: ThemeChoice; label: string; icon: typeof Sun }[] = [
    { value: 'system', label: 'Sistema', icon: Monitor },
    { value: 'dark', label: 'Oscuro', icon: Moon },
    { value: 'light', label: 'Claro', icon: Sun },
  ];
  return (
    <div role="radiogroup" aria-label="Tema" className={cn('grid grid-cols-3 gap-1 rounded border border-line bg-sunken p-1', className)}>
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={choice === o.value}
          onClick={() => {
            setChoice(o.value);
            applyTheme(o.value);
          }}
          className={cn('flex min-h-[34px] items-center justify-center gap-1.5 rounded-sm text-xs', choice === o.value ? 'bg-elevated text-fg' : 'text-fg-2 hover:text-fg')}
        >
          <o.icon className="h-3.5 w-3.5" aria-hidden />
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function UserMenu({ me }: { me: MeDTO | null }) {
  const { open, setOpen, ref } = useDisclosure();
  const router = useRouter();
  if (!me) {
    return (
      <Link href="/login" className="btn-secondary h-10 min-h-0 px-3">
        <LogIn className="h-4 w-4" aria-hidden />
        <span className="hidden sm:inline">Entrar</span>
      </Link>
    );
  }
  const main = me.characters.find((c) => c.isMain) ?? me.characters[0];
  const initials = me.user.displayName.slice(0, 2).toUpperCase();
  const logout = async () => {
    await clientApi('/v1/auth/logout', { method: 'POST', body: {} }).catch(() => {});
    router.push('/');
    router.refresh();
  };
  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        aria-haspopup="menu"
        className="grid h-10 w-10 place-items-center rounded-full border border-line-strong bg-elevated text-sm font-semibold text-fg hover:border-accent/70"
        aria-label={`Cuenta de ${me.user.displayName}`}
        style={main ? { color: classVar(main.classId) } : undefined}
      >
        {initials}
      </button>
      {open && (
        <div role="menu" className="absolute right-0 top-12 z-50 w-72 rounded-md border border-line-strong bg-surface p-2 shadow-tooltip">
          <div className="px-2 pb-2 pt-1">
            <p className="font-medium">{me.user.displayName}</p>
            <p className="truncate text-xs text-fg-3">{me.user.battleTag ?? me.user.email}</p>
          </div>
          {main && (
            <Link role="menuitem" href={characterHref(main.region, main.slug)} onClick={() => setOpen(false)} className="flex items-center justify-between rounded px-2 py-2 text-sm hover:bg-elevated">
              <span>
                Personaje principal
                <span className="block font-medium" style={{ color: classVar(main.classId) }}>
                  {main.displayName}
                </span>
              </span>
              <span className="t-num text-xs text-fg-3">nivel {main.level}</span>
            </Link>
          )}
          <Link role="menuitem" href="/settings" onClick={() => setOpen(false)} className="flex items-center gap-2 rounded px-2 py-2 text-sm hover:bg-elevated">
            <Settings className="h-4 w-4 text-fg-3" aria-hidden /> Ajustes y personajes
          </Link>
          <div className="px-2 py-2">
            <ThemeSwitch />
          </div>
          <button role="menuitem" type="button" onClick={logout} className="flex w-full items-center gap-2 rounded px-2 py-2 text-sm text-fg-2 hover:bg-elevated hover:text-fg">
            <LogOut className="h-4 w-4 text-fg-3" aria-hidden /> Cerrar sesión
          </button>
        </div>
      )}
    </div>
  );
}

interface NotificationList {
  unread: number;
  items: { id: string; title: string; body: string | null; link: string | null; readAt: string | null; createdAt: string }[];
}

export function NotificationsButton() {
  const { open, setOpen, ref } = useDisclosure();
  const [data, setData] = useState<NotificationList | null>(null);
  const load = () => clientApi<NotificationList>('/v1/notifications').then(setData).catch(() => {});
  useEffect(() => {
    void load();
  }, []);
  const markAll = async () => {
    await clientApi('/v1/notifications/read-all', { method: 'POST', body: {} }).catch(() => {});
    void load();
  };
  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="relative grid h-10 w-10 place-items-center rounded border border-transparent text-fg-2 hover:border-line hover:text-fg"
        aria-label={`Notificaciones${data?.unread ? `, ${data.unread} sin leer` : ''}`}
      >
        <Bell className="h-5 w-5" aria-hidden />
        {!!data?.unread && <span className="absolute right-1.5 top-1.5 grid h-4 min-w-4 place-items-center rounded-full bg-accent px-1 text-[10px] font-bold text-accent-on">{data.unread}</span>}
      </button>
      {open && (
        <div className="absolute right-0 top-12 z-50 w-80 rounded-md border border-line-strong bg-surface shadow-tooltip">
          <div className="flex items-center justify-between border-b border-line px-4 py-3">
            <p className="font-medium">Notificaciones</p>
            {!!data?.unread && (
              <button type="button" onClick={markAll} className="text-xs text-accent hover:underline">
                Marcar todo como leído
              </button>
            )}
          </div>
          <ul className="max-h-96 overflow-y-auto">
            {(data?.items ?? []).map((n) => (
              <li key={n.id} className={cn('border-b border-line/60 px-4 py-3 text-sm last:border-0', !n.readAt && 'bg-accent/5')}>
                {n.link ? (
                  <Link href={n.link} onClick={() => setOpen(false)} className="font-medium hover:underline">
                    {n.title}
                  </Link>
                ) : (
                  <p className="font-medium">{n.title}</p>
                )}
                <p className="text-xs text-fg-3">{relativeTime(n.createdAt)}</p>
              </li>
            ))}
            {data && !data.items.length && <li className="px-4 py-6 text-sm text-fg-2">Aquí verás convocatorias de raid y avisos de tus hermandades.</li>}
          </ul>
        </div>
      )}
    </div>
  );
}
