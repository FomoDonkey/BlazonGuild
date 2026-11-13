// Generates the probe's test textures (original artwork): a gold lozenge on transparency, 64×64,
// as uncompressed 32-bit TGA and as RGBA PNG, to learn which formats the WoW: Forever client draws.
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const out = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1')), 'BlazonGuildProbe');
const N = 64;

function pixel(x, y) {
  const cx = x - (N - 1) / 2;
  const cy = y - (N - 1) / 2;
  const d = (Math.abs(cx) + Math.abs(cy)) / (N / 2); // lozenge distance, 1 = edge
  if (d > 0.96) return [0, 0, 0, 0];
  const rim = d > 0.8;
  const shade = 1 - 0.55 * ((cy + N / 2) / N); // lit from the top
  const [r, g, b] = rim ? [120, 84, 30] : [236, 200, 120];
  return [Math.round(r * shade + 20), Math.round(g * shade + 10), Math.round(b * shade), 255];
}

// TGA (type 2, 32 bpp, top-left origin).
const tga = Buffer.alloc(18 + N * N * 4);
tga[2] = 2;
tga.writeUInt16LE(N, 12);
tga.writeUInt16LE(N, 14);
tga[16] = 32;
tga[17] = 0x28; // 8 alpha bits + top-left origin
for (let y = 0; y < N; y++)
  for (let x = 0; x < N; x++) {
    const [r, g, b, a] = pixel(x, y);
    const o = 18 + (y * N + x) * 4;
    tga[o] = b;
    tga[o + 1] = g;
    tga[o + 2] = r;
    tga[o + 3] = a;
  }
fs.writeFileSync(path.join(out, 'probe.tga'), tga);

// PNG (RGBA 8-bit).
const raw = Buffer.alloc(N * (N * 4 + 1));
for (let y = 0; y < N; y++) {
  raw[y * (N * 4 + 1)] = 0;
  for (let x = 0; x < N; x++) pixel(x, y).forEach((v, i) => (raw[y * (N * 4 + 1) + 1 + x * 4 + i] = v));
}
const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(zlib.crc32(td) >>> 0);
  return Buffer.concat([len, td, crc]);
};
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(N, 0);
ihdr.writeUInt32BE(N, 4);
ihdr[8] = 8;
ihdr[9] = 6;
const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
fs.writeFileSync(path.join(out, 'probe.png'), png);
console.log('texturas escritas en', out);
