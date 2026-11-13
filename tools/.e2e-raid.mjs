// E2E check of the raid planner against the running stack (dev verification fixture).
import { chromium } from 'playwright';

const base = 'http://localhost:3000';
const [raidPath, raidId] = process.argv.slice(2);
const b = await chromium.launch();
const ctx = await b.newContext({ viewport: { width: 1440, height: 1000 } });
const login = await ctx.request.post(base + '/api/v1/auth/login', { data: { email: 'verif-lider@forever.invalid', password: 'verificacion-local-123' } });
console.log('login', login.status());
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
await page.goto(base + raidPath, { waitUntil: 'networkidle' });

// 1. Pointer/touch flow: select a bench player, place it in group 3, save.
const bench = page.getByRole('region', { name: /Sin asignar/ });
const firstChip = bench.getByRole('button').filter({ hasText: /\w/ }).first();
const name = (await firstChip.innerText()).trim().split(/\r?\n/)[0].trim();
await firstChip.click();
await page.getByRole('region', { name: 'Grupo 3' }).getByRole('button', { name: 'Colocar aquí' }).first().click();
await page.getByRole('button', { name: /Guardar composición/ }).click();
await page.getByText('Composición guardada').waitFor({ timeout: 10000 });
const data = await (await ctx.request.get(base + '/api/v1/raids/' + raidId)).json();
const moved = data.signups.find((s) => s.character.displayName === name);
console.log('moved', name, '-> group', moved?.group, 'slot', moved?.slot, 'status', moved?.status);

// 2. Keyboard flow: focus a chip in group 1, Enter to select, then "Mover aquí" on the bench.
const g1 = page.getByRole('region', { name: 'Grupo 1' });
await g1.getByRole('button').first().focus();
await page.keyboard.press('Enter');
await page.getByRole('region', { name: /Sin asignar/ }).getByRole('button', { name: 'Mover aquí' }).click();
await page.getByRole('button', { name: /Guardar composición/ }).click();
await page.getByText('Composición guardada').waitFor({ timeout: 10000 });
const after = await (await ctx.request.get(base + '/api/v1/raids/' + raidId)).json();
console.log('benched', after.signups.filter((s) => s.status === 'BENCHED').map((s) => s.character.displayName).join(', '));

// 3. RBAC through the real stack: a raid leader must not read the audit log.
const audit = await ctx.request.get(base + '/api/v1/guilds/eu/' + encodeURIComponent('c-a-ñ-a-d-a') + '/audit');
console.log('audit as raid leader ->', audit.status());
console.log('page errors:', errors.length ? errors : 'none');
await b.close();
