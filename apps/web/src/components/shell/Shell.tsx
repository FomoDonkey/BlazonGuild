'use client';

import Link from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useRef, useState } from 'react';
import { ChevronRight, MoreHorizontal, PanelLeftClose, PanelLeftOpen, Search, X } from 'lucide-react';
import type { MeDTO } from '@blazonguild/types';
import { GuildCrest } from '@/components/game/GuildCrest';
import { guildHref, REGION_LABEL } from '@/lib/game';
import { cn } from '@/lib/utils';
import { globalNav, guildNav, isActive, settingsItem, type GuildContext, type NavItem } from './nav';
import { SearchDialog } from './SearchDialog';
import { NotificationsButton, UserMenu } from './UserMenu';

const ExploreIcon = globalNav[0].icon;

function activeKey(items: NavItem[], pathname: string, search: string) {
  const withQuery = items.find((i) => i.href.includes('?') && isActive(i, pathname, search));
  if (withQuery) return withQuery.key;
  return [...items].reverse().find((i) => !i.href.includes('?') && isActive(i, pathname, search))?.key ?? null;
}

function Wordmark({ collapsed }: { collapsed?: boolean }) {
  return (
    <Link href="/" className="group flex items-center gap-2.5 rounded px-1 py-1" aria-label="BlazonGuild, inicio">
      <svg viewBox="0 0 32 32" className="h-8 w-8 shrink-0" aria-hidden>
        <path d="M16 2 28 8v8c0 7-5.2 12.2-12 14C9.2 28.2 4 23 4 16V8z" fill="rgb(var(--c-sunken))" stroke="rgb(var(--c-accent))" strokeWidth="1.4" />
        {/* Original "B" monogram (two bowls cut out with evenodd) */}
        <path
          fillRule="evenodd"
          d="M11 8.5h6.4c3.1 0 5 1.6 5 4 0 1.5-.8 2.6-2.1 3.1 1.8.5 2.9 1.8 2.9 3.6 0 2.8-2.1 4.6-5.4 4.6H11zm3 2.6v3.7h3.1c1.4 0 2.2-.7 2.2-1.9 0-1.1-.8-1.8-2.2-1.8zm0 6.2v4.5h3.4c1.6 0 2.5-.8 2.5-2.2 0-1.5-.9-2.3-2.5-2.3z"
          fill="rgb(var(--c-accent))"
        />
      </svg>
      {!collapsed && (
        <span className="t-display text-gold text-[1.45rem] tracking-[0.05em]">BlazonGuild</span>
      )}
    </Link>
  );
}

function NavLinks({ items, active, collapsed, onNavigate }: { items: NavItem[]; active: string | null; collapsed?: boolean; onNavigate?: () => void }) {
  return (
    <ul className="space-y-0.5">
      {items.map((item) => {
        const on = item.key === active;
        const Icon = item.icon;
        return (
          <li key={item.key}>
            <Link
              href={item.href}
              onClick={onNavigate}
              aria-current={on ? 'page' : undefined}
              title={collapsed ? `${item.label}${item.soon ? ` (${item.soon})` : ''}` : undefined}
              className={cn(
                'group relative flex min-h-[40px] items-center gap-3 rounded px-3 text-sm transition-colors',
                on ? 'bg-gradient-to-r from-accent/[0.16] via-accent/[0.05] to-transparent text-fg shadow-[inset_0_0_0_1px_rgb(var(--c-accent)/0.18)]' : 'text-fg-2 hover:bg-white/[0.04] hover:text-fg',
                collapsed && 'justify-center px-0',
              )}
            >
              {on && <span aria-hidden className="absolute inset-y-1.5 left-0 w-[3px] rounded-r bg-gradient-to-b from-accent-hi via-accent to-accent-hi shadow-[0_0_10px_rgb(var(--c-accent)/0.7)]" />}
              <Icon className={cn('h-[18px] w-[18px] shrink-0', on ? 'text-accent' : 'text-fg-3 group-hover:text-fg-2')} aria-hidden />
              {!collapsed && (
                <>
                  <span className="truncate">{item.label}</span>
                  {item.soon && <span className="ml-auto text-2xs text-fg-3">{item.soon}</span>}
                </>
              )}
            </Link>
          </li>
        );
      })}
    </ul>
  );
}

function GuildBadge({ guild, collapsed }: { guild: GuildContext; collapsed?: boolean }) {
  return (
    <Link
      href={guildHref(guild.region, guild.slug)}
      className={cn('flex items-center gap-3 rounded-md border border-line bg-sunken/60 p-2 hover:border-line-strong', collapsed && 'justify-center border-transparent bg-transparent p-1')}
      title={collapsed ? guild.name : undefined}
    >
      <GuildCrest crest={guild.crest} name={guild.name} size={collapsed ? 36 : 40} />
      {!collapsed && (
        <span className="min-w-0">
          <span className="t-display block truncate text-base leading-tight">{guild.name}</span>
          <span className={cn('text-xs', guild.faction === 'HORDE' ? 'text-horde' : 'text-alliance')}>
            {guild.faction === 'HORDE' ? 'Horda' : 'Alianza'}
            <span className="text-fg-3"> en {REGION_LABEL[guild.region] ?? guild.region.toUpperCase()}</span>
          </span>
        </span>
      )}
    </Link>
  );
}

function Breadcrumbs({ guild }: { guild: GuildContext | null }) {
  const pathname = decodeURIComponent(usePathname());
  const parts = pathname.split('/').filter(Boolean);
  const crumbs: { href: string; label: string }[] = [];
  const LABEL: Record<string, string> = {
    roster: 'La hermandad', raids: 'Raids', rankings: 'Rankings', dungeons: 'Mazmorras', pvp: 'JcJ', pve: 'JcE',
    analytics: 'Analítica', events: 'Calendario', admin: 'Administración', settings: 'Ajustes', armory: 'Armería', login: 'Entrar', register: 'Crear cuenta',
  };
  const humanize = (s: string) => s.split('-').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
  if (parts[0] === 'g' && guild) {
    const base = guildHref(guild.region, guild.slug);
    crumbs.push({ href: base, label: guild.name });
    if (parts[3]) crumbs.push({ href: `${base}/${parts[3]}`, label: LABEL[parts[3]] ?? humanize(parts[3]) });
    if (parts[3] === 'raids' && parts[4]) crumbs.push({ href: pathname, label: 'Detalle' });
  } else if (parts[0] === 'c') {
    crumbs.push({ href: '/armory', label: 'Armería' });
    if (parts[2]) crumbs.push({ href: pathname, label: humanize(parts[2]) });
  } else if (parts[0]) {
    crumbs.push({ href: '/' + parts[0], label: LABEL[parts[0]] ?? humanize(parts[0]) });
  }
  if (!crumbs.length) return <span className="text-sm text-fg-2">Explorar hermandades</span>;
  return (
    <nav aria-label="Ruta de navegación" className="min-w-0">
      <ol className="flex min-w-0 items-center gap-1 text-sm">
        {crumbs.map((c, i) => {
          const last = i === crumbs.length - 1;
          return (
            <li key={c.href + i} className={cn('flex min-w-0 items-center gap-1', !last && 'hidden sm:flex')}>
              {/* On mobile only the current page is shown, so its separator would dangle. */}
              {i > 0 && <ChevronRight className="hidden h-3.5 w-3.5 shrink-0 text-fg-3 sm:block" aria-hidden />}
              {last ? (
                <span aria-current="page" className="truncate font-medium text-fg">
                  {c.label}
                </span>
              ) : (
                <Link href={c.href} className="truncate text-fg-2 hover:text-fg">
                  {c.label}
                </Link>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}

function ShellInner({ me, guild, children }: { me: MeDTO | null; guild: GuildContext | null; children: React.ReactNode }) {
  const pathname = usePathname();
  const search = useSearchParams().toString();
  const [collapsed, setCollapsed] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const moreRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    try {
      setCollapsed(localStorage.getItem('forever-sidebar') === 'collapsed');
    } catch {
      /* storage unavailable */
    }
  }, []);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      const typing = target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable);
      if ((e.key === 'k' && (e.metaKey || e.ctrlKey)) || (e.key === '/' && !typing)) {
        e.preventDefault();
        setSearchOpen(true);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);
  useEffect(() => {
    const d = moreRef.current;
    if (!d) return;
    if (moreOpen && !d.open) d.showModal();
    if (!moreOpen && d.open) d.close();
  }, [moreOpen]);
  useEffect(() => setMoreOpen(false), [pathname]);

  const toggle = () => {
    setCollapsed((c) => {
      try {
        localStorage.setItem('forever-sidebar', c ? 'expanded' : 'collapsed');
      } catch {
        /* ignore */
      }
      return !c;
    });
  };

  const primary = guild ? guildNav(guild) : globalNav;
  const allItems = [...primary, settingsItem];
  const active = activeKey(allItems, pathname, search);
  const memberships = me?.memberships ?? [];

  const mobileTabs: NavItem[] = guild
    ? primary.filter((i) => ['overview', 'guild', 'raids', 'rankings'].includes(i.key)).map((i) => (i.key === 'guild' ? { ...i, label: 'Roster' } : i))
    : [...globalNav, settingsItem];

  const sidebarBody = (isCollapsed: boolean, onNavigate?: () => void) => (
    <>
      {guild && (
        <div className={cn('px-3', isCollapsed && 'px-2')}>
          <GuildBadge guild={guild} collapsed={isCollapsed} />
        </div>
      )}
      <nav aria-label="Navegación principal" className={cn('mt-4 px-3', isCollapsed && 'px-2')}>
        <NavLinks items={primary} active={active} collapsed={isCollapsed} onNavigate={onNavigate} />
      </nav>
      {!isCollapsed && memberships.length > 0 && (
        <div className="mt-6 px-3">
          {/* A character belongs to one guild at a time; several entries only appear for alts in other guilds. */}
          <p className="px-3 pb-1.5 text-xs font-medium text-fg-3">{memberships.length === 1 ? 'Tu hermandad' : 'Hermandades de tus personajes'}</p>
          <ul className="space-y-0.5">
            {memberships.map((m) => {
              const chars = (me?.characters ?? []).filter((c) => c.guildSlug === m.guild.slug).map((c) => c.displayName);
              return (
                <li key={m.guild.id}>
                  <Link href={guildHref(m.guild.region, m.guild.slug)} onClick={onNavigate} className="flex min-h-[40px] items-center gap-2.5 rounded px-3 text-sm text-fg-2 hover:bg-white/[0.04] hover:text-fg">
                    <GuildCrest crest={m.guild.crest} name={m.guild.name} size={24} />
                    <span className="min-w-0">
                      <span className="block truncate">{m.guild.name}</span>
                      {chars.length > 0 && <span className="block truncate text-2xs text-fg-3">con {chars.join(', ')}</span>}
                    </span>
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      )}
      {guild && !isCollapsed && (
        <div className="mt-6 px-3">
          <Link href="/" onClick={onNavigate} className="flex min-h-[36px] items-center gap-3 rounded px-3 text-sm text-fg-2 hover:bg-elevated/60 hover:text-fg">
            <ExploreIcon className="h-[18px] w-[18px] text-fg-3" aria-hidden />
            Explorar otras hermandades
          </Link>
        </div>
      )}
    </>
  );

  return (
    <div className="min-h-dvh md:flex">
      {/* Desktop / tablet sidebar */}
      <aside
        className={cn(
          'surface-metal sticky top-0 hidden h-dvh shrink-0 flex-col border-r border-black/80 shadow-[inset_-1px_0_0_rgb(var(--c-accent)/0.22)] md:flex',
          collapsed ? 'w-[72px]' : 'w-[72px] lg:w-[264px]',
        )}
      >
        <div className={cn('flex h-14 items-center px-4', collapsed ? 'justify-center px-2' : 'justify-center lg:justify-start')}>
          <span className="hidden lg:block">
            <Wordmark collapsed={collapsed} />
          </span>
          <span className="lg:hidden">
            <Wordmark collapsed />
          </span>
        </div>
        <div className="scrollbar-thin flex-1 overflow-y-auto pb-4">
          <div className="hidden lg:block">{sidebarBody(collapsed)}</div>
          <div className="lg:hidden">{sidebarBody(true)}</div>
        </div>
        <div className={cn('border-t border-line p-3', collapsed && 'px-2')}>
          <NavLinks items={[settingsItem]} active={active} collapsed={collapsed} />
          <button type="button" onClick={toggle} className="mt-1 hidden min-h-[40px] w-full items-center gap-3 rounded px-3 text-sm text-fg-3 hover:bg-elevated/60 hover:text-fg lg:flex" aria-label={collapsed ? 'Expandir barra lateral' : 'Contraer barra lateral'}>
            {collapsed ? <PanelLeftOpen className="mx-auto h-[18px] w-[18px]" aria-hidden /> : <PanelLeftClose className="h-[18px] w-[18px]" aria-hidden />}
            {!collapsed && 'Contraer'}
          </button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-40 flex h-14 items-center gap-3 bg-canvas/90 px-4 backdrop-blur supports-[backdrop-filter]:bg-canvas/70 sm:px-6">
          <span aria-hidden className="rule-gold absolute inset-x-0 bottom-0 opacity-50" />
          <span className="md:hidden">
            <Wordmark collapsed />
          </span>
          <div className="min-w-0 flex-1">
            <Breadcrumbs guild={guild} />
          </div>
          <button
            type="button"
            onClick={() => setSearchOpen(true)}
            className="flex h-10 shrink-0 items-center gap-2 whitespace-nowrap rounded border border-line bg-surface px-3 text-sm text-fg-3 hover:border-line-strong hover:text-fg-2 sm:w-56 lg:w-72"
            aria-label="Buscar hermandades y personajes"
          >
            <Search className="h-4 w-4" aria-hidden />
            <span className="hidden sm:inline">Buscar…</span>
            <kbd className="ml-auto hidden whitespace-nowrap rounded border border-line px-1.5 font-sans text-2xs text-fg-3 lg:inline">Ctrl K</kbd>
          </button>
          {me && <NotificationsButton />}
          <UserMenu me={me} />
        </header>

        <main id="main" className="flex-1 pb-24 md:pb-10">
          {children}
        </main>
      </div>

      {/* Mobile bottom navigation */}
      <nav aria-label="Navegación principal" className="surface-metal fixed inset-x-0 bottom-0 z-40 border-t border-black pb-[env(safe-area-inset-bottom)] shadow-[0_-1px_0_rgb(var(--c-accent)/0.25)] md:hidden">
        <ul className="grid grid-cols-5">
          {mobileTabs.slice(0, 4).map((item) => {
            const on = item.key === active;
            const Icon = item.icon;
            return (
              <li key={item.key}>
                <Link href={item.href} aria-current={on ? 'page' : undefined} className={cn('flex h-16 flex-col items-center justify-center gap-1 text-2xs', on ? 'text-accent' : 'text-fg-2')}>
                  <Icon className="h-5 w-5" aria-hidden />
                  <span className="max-w-full truncate px-1">{item.label}</span>
                </Link>
              </li>
            );
          })}
          <li>
            <button type="button" onClick={() => setMoreOpen(true)} className="flex h-16 w-full flex-col items-center justify-center gap-1 text-2xs text-fg-2" aria-haspopup="dialog">
              <MoreHorizontal className="h-5 w-5" aria-hidden />
              Más
            </button>
          </li>
        </ul>
      </nav>

      <dialog
        ref={moreRef}
        onClose={() => setMoreOpen(false)}
        onClick={(e) => e.target === e.currentTarget && setMoreOpen(false)}
        className="m-0 mt-auto max-h-[85dvh] w-full max-w-none rounded-t-lg border border-line bg-surface p-0 text-fg backdrop:bg-black/60 md:hidden"
        aria-label="Todas las secciones"
      >
        <div className="flex items-center justify-between border-b border-line px-4 py-3">
          <p className="t-display text-lg">Secciones</p>
          <button type="button" onClick={() => setMoreOpen(false)} className="btn-ghost h-10 w-10 px-0" aria-label="Cerrar">
            <X className="h-5 w-5" aria-hidden />
          </button>
        </div>
        <div className="max-h-[70dvh] overflow-y-auto py-4">
          {sidebarBody(false, () => setMoreOpen(false))}
          <div className="mt-2 px-3">
            <NavLinks items={[settingsItem]} active={active} onNavigate={() => setMoreOpen(false)} />
          </div>
        </div>
      </dialog>

      <SearchDialog open={searchOpen} onClose={() => setSearchOpen(false)} defaultRegion={guild?.region ?? 'eu'} />
    </div>
  );
}

export function Shell(props: { me: MeDTO | null; guild: GuildContext | null; children: React.ReactNode }) {
  return (
    <Suspense fallback={<div className="min-h-dvh">{props.children}</div>}>
      <ShellInner {...props} />
    </Suspense>
  );
}
