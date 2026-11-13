const rtf = new Intl.RelativeTimeFormat('es', { numeric: 'auto' });
const nf = new Intl.NumberFormat('es-ES');
const nf1 = new Intl.NumberFormat('es-ES', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const nf2 = new Intl.NumberFormat('es-ES', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export const fmtInt = (n: number | null | undefined) => (n === null || n === undefined ? '—' : nf.format(Math.round(n)));
export const fmt1 = (n: number | null | undefined) => (n === null || n === undefined ? '—' : nf1.format(n));
export const fmt2 = (n: number | null | undefined) => (n === null || n === undefined ? '—' : nf2.format(n));
export const fmtPct = (n: number | null | undefined) => (n === null || n === undefined ? '—' : `${nf2.format(n)} %`);

export function relativeTime(iso: string | null | undefined, now = Date.now()) {
  if (!iso) return '—';
  const diff = new Date(iso).getTime() - now;
  const abs = Math.abs(diff);
  const units: [Intl.RelativeTimeFormatUnit, number][] = [
    ['year', 365 * 86_400_000],
    ['month', 30 * 86_400_000],
    ['week', 7 * 86_400_000],
    ['day', 86_400_000],
    ['hour', 3_600_000],
    ['minute', 60_000],
  ];
  for (const [unit, ms] of units) if (abs >= ms) return rtf.format(Math.round(diff / ms), unit);
  return 'ahora mismo';
}

const dateFmt = new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Europe/Madrid' });
const dateShort = new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'short', timeZone: 'Europe/Madrid' });
const dateTime = new Intl.DateTimeFormat('es-ES', { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Madrid' });
const timeFmt = new Intl.DateTimeFormat('es-ES', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Madrid' });
const weekday = new Intl.DateTimeFormat('es-ES', { weekday: 'short', timeZone: 'Europe/Madrid' });
const dayNum = new Intl.DateTimeFormat('es-ES', { day: 'numeric', timeZone: 'Europe/Madrid' });
const monthShort = new Intl.DateTimeFormat('es-ES', { month: 'short', timeZone: 'Europe/Madrid' });

export const fmtDate = (iso: string | null | undefined) => (iso ? dateFmt.format(new Date(iso)) : '—');
export const fmtDateShort = (iso: string | null | undefined) => (iso ? dateShort.format(new Date(iso)) : '—');
export const fmtDateTime = (iso: string | null | undefined) => (iso ? dateTime.format(new Date(iso)) : '—');
export const fmtTime = (iso: string | null | undefined) => (iso ? timeFmt.format(new Date(iso)) : '—');
export const calendarParts = (iso: string) => {
  const d = new Date(iso);
  return { weekday: weekday.format(d), day: dayNum.format(d), month: monthShort.format(d) };
};

export const plural = (n: number, one: string, many: string) => `${fmtInt(n)} ${n === 1 ? one : many}`;
