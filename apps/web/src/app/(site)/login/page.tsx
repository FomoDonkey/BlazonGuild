import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { Suspense } from 'react';
import { AuthForm } from '@/components/auth/AuthForm';
import { CinematicHero } from '@/components/art/CinematicHero';
import { zoneArt } from '@/components/art/raid-art';
import { apiOrNull, getMe } from '@/lib/api';

export const metadata: Metadata = { title: 'Entrar' };

export default async function LoginPage() {
  if (await getMe()) redirect('/');
  const providers = await apiOrNull<{ battlenet: boolean }>('/v1/auth/providers');
  return (
    <CinematicHero art={zoneArt('ONY')} embers={40} artOpacity={0.5} className="min-h-[calc(100dvh-3.5rem)]">
    <div className="plate mx-auto my-10 max-w-sm rounded-[4px] px-6 py-8 sm:my-16">
      <h1 className="t-display text-gold text-3xl">Entrar en BlazonGuild</h1>
      <p className="mt-2 text-sm text-fg-2">Para inscribirte en raids y ver lo privado de tu hermandad.</p>
      <div className="mt-8">
        <Suspense>
          <AuthForm mode="login" battlenetEnabled={!!providers?.battlenet} />
        </Suspense>
      </div>
    </div>
    </CinematicHero>
  );
}
