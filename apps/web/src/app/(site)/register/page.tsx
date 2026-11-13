import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { Suspense } from 'react';
import { AuthForm } from '@/components/auth/AuthForm';
import { CinematicHero } from '@/components/art/CinematicHero';
import { zoneArt } from '@/components/art/raid-art';
import { apiOrNull, getMe } from '@/lib/api';

export const metadata: Metadata = { title: 'Crear cuenta' };

export default async function RegisterPage() {
  if (await getMe()) redirect('/');
  const providers = await apiOrNull<{ battlenet: boolean }>('/v1/auth/providers');
  return (
    <CinematicHero art={zoneArt('ONY')} embers={40} artOpacity={0.5} className="min-h-[calc(100dvh-3.5rem)]">
    <div className="plate mx-auto my-10 max-w-sm rounded-[4px] px-6 py-8 sm:my-16">
      <h1 className="t-display text-gold text-3xl">Crear cuenta</h1>
      <p className="mt-2 text-sm text-fg-2">Tu cuenta de BlazonGuild sirve para todas tus hermandades y personajes.</p>
      <div className="mt-8">
        <Suspense>
          <AuthForm mode="register" battlenetEnabled={!!providers?.battlenet} />
        </Suspense>
      </div>
    </div>
    </CinematicHero>
  );
}
