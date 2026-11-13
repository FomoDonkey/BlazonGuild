/** Usage: npm run sync:guild -- <region> <guild-slug> [--all] */
import { isRegion } from '@blazonguild/types';
import { createDeps } from '../deps';
import { loadEnv } from '../env';

const [region, slug] = process.argv.slice(2).filter((a) => !a.startsWith('--'));
if (!region || !slug || !isRegion(region)) {
  console.error('Uso: npm run sync:guild -- <eu|us|kr|tw> <slug-de-hermandad> [--all]');
  process.exit(1);
}
const { deps, close } = await createDeps({ ...loadEnv(), DISABLE_SCHEDULER: true });
const started = Date.now();
const guild = await deps.sync.syncGuild(region, slug, { trigger: 'CLI', details: process.argv.includes('--all') ? 'all' : 'stale', awaitDetails: true });
console.log(JSON.stringify({ guild: guild.name, members: guild.memberCount, faction: guild.faction, ruleset: guild.rulesetName, seconds: (Date.now() - started) / 1000 }, null, 2));
await deps.sync.drain();
await close();
