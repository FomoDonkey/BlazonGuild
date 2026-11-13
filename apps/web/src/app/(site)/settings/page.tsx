import type { Metadata } from 'next';
import Link from 'next/link';
import { BadgeCheck, CircleDashed } from 'lucide-react';
import { SettingsClient } from '@/components/settings/SettingsClient';
import { ThemeSwitch } from '@/components/shell/UserMenu';
import { EmptyState } from '@/components/ui/states';
import { apiOrNull, getMe } from '@/lib/api';
import { fmtDate } from '@/lib/format';
import { characterHref, classVar } from '@/lib/game';
import { GUILD_ROLE_LABEL } from '@blazonguild/types';

export const metadata: Metadata = { title: 'Ajustes' };

export default async function SettingsPage() {
  const me = await getMe();
  const providers = await apiOrNull<{ battlenet: boolean }>('/v1/auth/providers');
  return (
    <div className="mx-auto max-w-3xl space-y-12 px-4 py-10 sm:px-6">
      <header>
        <h1 className="t-display text-3xl sm:text-4xl">Ajustes</h1>
      </header>

      <section aria-labelledby="appearance" className="space-y-3">
        <h2 id="appearance" className="t-display text-xl">
          Apariencia
        </h2>
        <p className="text-sm text-fg-2">El tema se guarda en este navegador.</p>
        <ThemeSwitch className="max-w-sm" />
      </section>

      {!me ? (
        <EmptyState title="Entra para gestionar tu cuenta" action={{ href: '/login?returnTo=/settings', label: 'Entrar' }}>
          Con una cuenta puedes vincular tus personajes, inscribirte en raids y conectar la app compañera del addon.
        </EmptyState>
      ) : (
        <>
          <section aria-labelledby="account" className="space-y-3">
            <h2 id="account" className="t-display text-xl">
              Cuenta
            </h2>
            <dl className="grid gap-x-8 gap-y-2 text-sm sm:grid-cols-[10rem_1fr]">
              <dt className="text-fg-3">Nombre</dt>
              <dd>{me.user.displayName}</dd>
              <dt className="text-fg-3">Email</dt>
              <dd>{me.user.email.endsWith('@battlenet.invalid') ? 'Cuenta creada con Battle.net' : me.user.email}</dd>
              <dt className="text-fg-3">Battle.net</dt>
              <dd>{me.user.battleTag ?? 'Sin vincular'}</dd>
              <dt className="text-fg-3">Miembro desde</dt>
              <dd>{fmtDate(me.user.createdAt)}</dd>
            </dl>
          </section>

          <section aria-labelledby="characters" className="space-y-3">
            <h2 id="characters" className="t-display text-xl">
              Personajes
            </h2>
            <p className="max-w-prose text-sm text-fg-2">
              Al vincular Battle.net, BlazonGuild comprueba qué personajes son tuyos y te da acceso a sus hermandades según el rango de cada uno. Nadie puede reclamar un personaje ajeno.
            </p>
            <SettingsClient battlenetEnabled={!!providers?.battlenet} characters={me.characters} />
            {me.characters.length > 0 && (
              <ul className="divide-y divide-line border-y border-line">
                {me.characters.map((c) => (
                  <li key={c.id} className="flex items-center justify-between gap-3 py-2.5 text-sm">
                    <Link href={characterHref(c.region, c.slug)} className="font-semibold hover:underline" style={{ color: classVar(c.classId) }}>
                      {c.displayName}
                    </Link>
                    <span className="flex items-center gap-3 text-xs text-fg-3">
                      <span className="t-num">nivel {c.level}</span>
                      {c.verified ? (
                        <span className="inline-flex items-center gap-1 text-success">
                          <BadgeCheck className="h-3.5 w-3.5" aria-hidden /> verificado
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-warning">
                          <CircleDashed className="h-3.5 w-3.5" aria-hidden /> vinculado por un administrador
                        </span>
                      )}
                      {c.isMain && <span className="text-accent">principal</span>}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </section>

          {me.memberships.length > 0 && (
            <section aria-labelledby="memberships" className="space-y-3">
              <h2 id="memberships" className="t-display text-xl">
                {me.memberships.length === 1 ? 'Tu hermandad' : 'Hermandades de tus personajes'}
              </h2>
              <ul className="divide-y divide-line border-y border-line text-sm">
                {me.memberships.map((m) => (
                  <li key={m.guild.id} className="flex justify-between py-2.5">
                    <span>{m.guild.name}</span>
                    <span className="text-fg-2">
                      {GUILD_ROLE_LABEL[m.role]}
                      {!m.verified && <span className="text-fg-3"> (asignado manualmente)</span>}
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}
    </div>
  );
}
