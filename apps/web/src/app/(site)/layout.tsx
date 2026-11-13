import { Shell } from '@/components/shell/Shell';
import { getMe } from '@/lib/api';

export default async function SiteLayout({ children }: { children: React.ReactNode }) {
  const me = await getMe();
  return (
    <Shell me={me} guild={null}>
      {children}
    </Shell>
  );
}
