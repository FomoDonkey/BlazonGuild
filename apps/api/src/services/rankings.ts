import { characters, eq, guilds } from '@blazonguild/database';
import { blizzardProvenance, classById, specById, type RankingBoardDTO, type RankingMetric, type CombatRole } from '@blazonguild/types';
import type { AppDeps } from '../context';
import { toRosterMember } from './mappers';

type GuildRow = typeof guilds.$inferSelect;
type CharacterRow = typeof characters.$inferSelect;

interface MetricDef {
  label: string;
  unit: string;
  value: (c: CharacterRow) => number | null;
  detail?: (c: CharacterRow) => string | null;
  calculation: string;
  eligibility: string;
  requiresDetail: boolean;
}

const bestProfession = (c: CharacterRow) => {
  const primaries = (c.professions ?? []).filter((p) => p.kind === 'primary');
  if (!primaries.length) return null;
  return primaries.reduce((a, b) => (b.skill > a.skill ? b : a));
};

const METRICS: Partial<Record<RankingMetric, MetricDef>> = {
  level: {
    label: 'Nivel', unit: 'nivel', value: (c) => c.level, requiresDetail: false,
    calculation: 'Nivel actual del personaje según el roster oficial de la hermandad.',
    eligibility: 'Todos los personajes del roster.',
  },
  item_level: {
    label: 'Nivel de objeto equipado', unit: 'iLvl', value: (c) => (c.equippedItemLevel && c.equippedItemLevel > 0 ? c.equippedItemLevel : null), requiresDetail: true,
    calculation: 'Campo `equipped_item_level` del perfil (media del equipo puesto en el momento de la captura).',
    eligibility: 'Personajes con perfil completo sincronizado y equipo visible.',
  },
  honorable_kills: {
    label: 'Muertes con honor', unit: 'MCH', value: (c) => c.honorableKills, requiresDetail: true,
    calculation: 'Total acumulado de `honorable_kills` del resumen JcJ del personaje.',
    eligibility: 'Personajes con resumen JcJ disponible.',
  },
  achievement_points: {
    label: 'Puntos de logro', unit: 'pts', value: (c) => c.achievementPoints, requiresDetail: true,
    calculation: 'Campo `total_points` del resumen de logros.',
    eligibility: 'Personajes con resumen de logros disponible.',
  },
  profession_skill: {
    label: 'Profesión principal más alta', unit: 'puntos', requiresDetail: true,
    value: (c) => bestProfession(c)?.skill ?? null,
    detail: (c) => {
      const p = bestProfession(c);
      return p ? `${p.name} ${p.skill}/${p.max}` : null;
    },
    calculation: 'Máximo de puntos de habilidad entre las profesiones principales del personaje.',
    eligibility: 'Personajes con al menos una profesión principal.',
  },
};

const UNAVAILABLE: Partial<Record<RankingMetric, { label: string; unit: string; reason: string }>> = {
  dps: { label: 'Daño por segundo', unit: 'DPS', reason: 'Battle.net no expone métricas de combate. Requiere procesar registros de combate (WoWCombatLog.txt) con el motor de analítica (Fase 5).' },
  hps: { label: 'Sanación por segundo', unit: 'HPS', reason: 'Battle.net no expone métricas de combate. Requiere procesar registros de combate (Fase 5).' },
  attendance: { label: 'Asistencia a raids', unit: '%', reason: 'Se calculará a partir de raids completadas con asistencia registrada (addon o logs, Fases 5–7). Las inscripciones por sí solas no prueban asistencia.' },
};

export const RANKING_METRICS = [...Object.keys(METRICS), ...Object.keys(UNAVAILABLE)] as RankingMetric[];

export async function rankingBoard(
  deps: AppDeps,
  guild: GuildRow,
  metric: RankingMetric,
  filters: { classId?: number; role?: CombatRole; minLevel?: number; limit?: number },
): Promise<RankingBoardDTO> {
  const unavailable = UNAVAILABLE[metric];
  if (unavailable) {
    return {
      metric, label: unavailable.label, unit: unavailable.unit, available: false, unavailableReason: unavailable.reason,
      methodology: { calculation: '—', period: '—', eligibility: '—', source: 'Registro de combate / addon', verification: 'No disponible', sorting: '—' },
      sampleSize: 0, eligibleTotal: 0, entries: [], provenance: { source: 'UNAVAILABLE', status: 'UNAVAILABLE', confidence: 0, collectedAt: null },
    };
  }
  const def = METRICS[metric]!;
  let rows = await deps.db.select().from(characters).where(eq(characters.guildId, guild.id));
  if (filters.classId) rows = rows.filter((r) => r.classId === filters.classId);
  if (filters.role) rows = rows.filter((r) => specById(r.primarySpecId)?.roleHint === filters.role);
  if (filters.minLevel) rows = rows.filter((r) => r.level >= filters.minLevel!);
  const eligibleTotal = rows.length;
  const scored = rows
    .filter((r) => !def.requiresDetail || r.detailState === 'OK')
    .map((r) => ({ r, v: def.value(r) }))
    .filter((x): x is { r: CharacterRow; v: number } => x.v !== null)
    .sort((a, b) => b.v - a.v || b.r.level - a.r.level || a.r.name.localeCompare(b.r.name));

  // Standard competition ranking: ties share a position (1, 2, 2, 4…).
  let position = 0;
  let last: number | null = null;
  const entries = scored.slice(0, filters.limit ?? 100).map((x, i) => {
    if (x.v !== last) position = i + 1;
    last = x.v;
    return { position, member: toRosterMember(x.r, guild.settings?.rankNames), value: x.v, detail: def.detail?.(x.r) ?? null };
  });
  const classLabel = filters.classId ? ` · ${classById(filters.classId)?.nameEs}` : '';
  const oldest = scored.reduce<Date | null>((acc, x) => {
    const d = x.r.detailSyncedAt ?? x.r.rosterSeenAt;
    return d && (!acc || d < acc) ? d : acc;
  }, null);
  return {
    metric,
    label: def.label + classLabel,
    unit: def.unit,
    available: true,
    unavailableReason: null,
    methodology: {
      calculation: def.calculation,
      period: 'Valor actual (última sincronización de cada personaje)',
      eligibility: def.eligibility + (filters.role ? ' Filtrado por rol estimado a partir de la rama con más talentos.' : ''),
      source: 'API Battle.net (namespace profile-forever)',
      verification: 'Datos de servidor verificados; ninguna cifra es introducida por usuarios.',
      sorting: 'Descendente por valor; empates comparten posición y se ordenan por nivel y nombre.',
    },
    sampleSize: scored.length,
    eligibleTotal,
    entries,
    provenance: blizzardProvenance(oldest, { method: 'ranking over latest character snapshots', notes: `Muestra ${scored.length} de ${eligibleTotal}` }),
  };
}
