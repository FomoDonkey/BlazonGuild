/** Usage: npm run admin:create -- <email> <display-name>   (password read from BLAZONGUILD_ADMIN_PASSWORD) */
import { eq, users } from '@blazonguild/database';
import { createDeps } from '../deps';
import { loadEnv } from '../env';
import { hashPassword } from '../lib/crypto';
import { audit } from '../lib/audit';

const [emailArg, ...nameParts] = process.argv.slice(2);
const password = process.env.BLAZONGUILD_ADMIN_PASSWORD;
if (!emailArg || !password || password.length < 12) {
  console.error('Uso: BLAZONGUILD_ADMIN_PASSWORD=<min 12 caracteres> npm run admin:create -- <email> <nombre>');
  process.exit(1);
}
const email = emailArg.trim().toLowerCase();
const { deps, close } = await createDeps({ ...loadEnv(), DISABLE_SCHEDULER: true });
const existing = (await deps.db.select().from(users).where(eq(users.email, email)).limit(1))[0];
const passwordHash = await hashPassword(password);
const [user] = existing
  ? await deps.db.update(users).set({ platformRole: 'ADMIN', passwordHash }).where(eq(users.id, existing.id)).returning()
  : await deps.db.insert(users).values({ email, displayName: nameParts.join(' ') || 'Administrador', passwordHash, platformRole: 'ADMIN' }).returning();
await audit(deps.db, { actorUserId: null, action: 'ADMIN_BOOTSTRAP', entity: 'user', entityId: user.id, changes: { email } });
console.log(`Administrador listo: ${user.email} (${user.id})`);
await close();
