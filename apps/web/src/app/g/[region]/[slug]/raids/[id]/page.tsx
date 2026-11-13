import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Lock } from 'lucide-react';
import type { RaidDetailDTO } from '@blazonguild/types';
import { CinematicHero } from '@/components/art/CinematicHero';
import { zoneArt } from '@/components/art/raid-art';
import { RaidPlanner } from '@/components/raids/RaidPlanner';
import { SignupPanel } from '@/components/raids/SignupPanel';
import { EmptyState } from '@/components/ui/states';
import { api, ApiFailure } from '@/lib/api';
import { fmtDateTime, fmtTime } from '@/lib/format';
import { guildHref } from '@/lib/game';

type Props = { params: Promise<{ region: string; slug: string; id: string }> };

export const metadata: Metadata = { title: 'Raid' };

const STATUS_LABEL = { SCHEDULED: 'Convocada', IN_PROGRESS: 'En curso', COMPLETED: 'Completada', CANCELLED: 'Cancelada' } as const;

export default async function RaidDetailPage({ params }: Props) {
  const { region, slug, id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  let raid: RaidDetailDTO;
  try {
    raid = await api<RaidDetailDTO>(`/v1/raids/${id}`);
  } catch (err) {
    if (err instanceof ApiFailure && err.status === 404) notFound();
    if (err instanceof ApiFailure && (err.status === 401 || err.status === 403)) {
      return (
        <div className="mx-auto max-w-2xl px-4 py-12 sm:px-6">
          <EmptyState icon={Lock} title="Esta raid es privada" action={{ href: `/login?returnTo=${encodeURIComponent(guildHref(region, slug, `/raids/${id}`))}`, label: 'Entrar' }}>
            Solo los miembros verificados de la hermandad pueden ver sus convocatorias.
          </EmptyState>
        </div>
      );
    }
    throw err;
  }
  const canManage = raid.viewer.permissions.includes('raids.manage');

  return (
    <div>
    <CinematicHero art={zoneArt(raid.instanceKey)} embers={35} artOpacity={0.6} className="border-b border-black">
    <div className="mx-auto max-w-7xl px-4 pb-2 pt-8 sm:px-6">
      <Link href={guildHref(region, slug, '/raids')} className="inline-flex items-center gap-1.5 text-sm text-white/70 hover:text-white">
        <ArrowLeft className="h-4 w-4" aria-hidden /> Todas las raids
      </Link>
      <header className="mt-3 flex flex-col gap-4 pb-6 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className="text-sm text-accent">{raid.instanceName}</p>
          <h1 className="mt-1">
            <span className="t-display text-gold inline-block text-4xl sm:text-5xl">{raid.title}</span>
          </h1>
          <p className="mt-2 text-fg-2">
            {fmtDateTime(raid.startsAt)}
            {raid.endsAt && <> hasta las {fmtTime(raid.endsAt)}</>}
            {raid.leader && <span className="text-fg-3">. Lidera {raid.leader}</span>}
          </p>
        </div>
        <dl className="flex flex-wrap gap-x-8 gap-y-3">
          <div>
            <dt className="text-xs text-fg-3">Estado</dt>
            <dd className={raid.status === 'CANCELLED' ? 'text-danger' : 'text-success'}>{STATUS_LABEL[raid.status]}</dd>
          </div>
          <div>
            <dt className="text-xs text-fg-3">Confirmados</dt>
            <dd className="t-figure text-2xl leading-none">
              {raid.counts.confirmed}
              <span className="font-sans text-sm text-fg-3">/{raid.capacity}</span>
            </dd>
          </div>
          <div>
            <dt className="text-xs text-fg-3">Tentativos</dt>
            <dd className="t-figure text-2xl leading-none">{raid.counts.tentative}</dd>
          </div>
          <div>
            <dt className="text-xs text-fg-3">Banquillo</dt>
            <dd className="t-figure text-2xl leading-none">{raid.counts.benched}</dd>
          </div>
        </dl>
      </header>
    </div>
    </CinematicHero>
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
      <div className="grid gap-8 xl:grid-cols-[minmax(0,1fr)_320px]">
        <section aria-labelledby="planner">
          <h2 id="planner" className="t-display mb-4 text-xl">
            Composición
          </h2>
          {raid.signups.length ? (
            <RaidPlanner raid={raid} canManage={canManage} />
          ) : (
            <EmptyState title="Todavía no hay inscritos">Cuando los miembros se inscriban, aparecerán aquí listos para repartir en grupos.</EmptyState>
          )}
        </section>
        <div className="space-y-6">
          <SignupPanel raid={raid} />
          {raid.notes && (
            <section aria-labelledby="notes" className="rounded-md border border-line p-4">
              <h2 id="notes" className="text-sm font-medium">
                Notas del liderazgo
              </h2>
              <p className="mt-2 whitespace-pre-line text-sm text-fg-2">{raid.notes}</p>
            </section>
          )}
          <section aria-labelledby="comments">
            <h2 id="comments" className="text-sm font-medium">
              Comentarios de los inscritos
            </h2>
            <ul className="mt-2 space-y-2 text-sm">
              {raid.signups.filter((s) => s.comment).map((s) => (
                <li key={s.id} className="text-fg-2">
                  <span className="font-medium text-fg">{s.character.displayName}:</span> {s.comment}
                </li>
              ))}
              {!raid.signups.some((s) => s.comment) && <li className="text-fg-3">Sin comentarios.</li>}
            </ul>
          </section>
        </div>
      </div>
    </div>
    </div>
  );
}
