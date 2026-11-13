// Starts BlazonGuild Core API (port 3001) and the web platform (port 3000) together.
import { spawn } from 'node:child_process';

const procs = [
  ['api', ['run', 'dev', '-w', '@blazonguild/api']],
  ['web', ['run', 'dev', '-w', '@blazonguild/web']],
].map(([name, args]) => {
  const p = spawn(process.platform === 'win32' ? 'npm.cmd' : 'npm', args, { stdio: ['ignore', 'pipe', 'pipe'], shell: process.platform === 'win32' });
  const tag = name === 'api' ? '\x1b[33m[api]\x1b[0m' : '\x1b[36m[web]\x1b[0m';
  for (const s of [p.stdout, p.stderr]) s.on('data', (d) => process.stdout.write(String(d).split('\n').filter(Boolean).map((l) => `${tag} ${l}`).join('\n') + '\n'));
  p.on('exit', (code) => console.log(`${tag} terminó (${code})`));
  return p;
});
const stop = () => procs.forEach((p) => p.kill());
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
