/**
 * BlazonGuild data provenance contract (ADR-003).
 * Every meaningful value shown to users carries where it came from and how sure we are.
 */

export const PROVENANCE_SOURCES = [
  'BLIZZARD_API', // Battle.net Game Data / Profile API
  'ADDON_COLLECTED', // In-game addon via SavedVariables + companion upload
  'COMBAT_LOG', // Parsed WoWCombatLog.txt
  'MANUAL', // Typed in by a member (sign-ups, availability)
  'CALCULATED', // Derived deterministically from the sources above
  'ESTIMATED', // Heuristic / inferred (e.g. role from talent distribution)
  'UNAVAILABLE',
] as const;
export type ProvenanceSource = (typeof PROVENANCE_SOURCES)[number];

export type VerificationStatus =
  | 'VERIFIED' // Authoritative source (server data) or ownership proven via Battle.net OAuth
  | 'UNVERIFIED' // Plausible but not proven (addon uploads, manual claims)
  | 'DERIVED' // Computed from verified inputs
  | 'HEURISTIC' // Inference, shown with a warning
  | 'UNAVAILABLE';

export interface Provenance {
  source: ProvenanceSource;
  status: VerificationStatus;
  /** 0..1 */
  confidence: number;
  /** ISO 8601 UTC */
  collectedAt: string | null;
  endpoint?: string;
  namespace?: string;
  checksum?: string;
  method?: string;
  processorVersion?: string;
  notes?: string;
}

/**
 * Battle.net WoW: Forever endpoints are not (yet) part of Blizzard's public documentation,
 * but they answer with stable schemas (live-probed 2026-11-09 and 2026-11-12).
 * We therefore treat them as authoritative server data with slightly reduced confidence.
 */
export const BLIZZARD_FOREVER_CONFIDENCE = 0.9;

export function blizzardProvenance(collectedAt: Date | string | null, extra?: Partial<Provenance>): Provenance {
  return {
    source: 'BLIZZARD_API',
    status: 'VERIFIED',
    confidence: BLIZZARD_FOREVER_CONFIDENCE,
    collectedAt: collectedAt ? new Date(collectedAt).toISOString() : null,
    ...extra,
  };
}

export const PROVENANCE_LABEL: Record<ProvenanceSource, string> = {
  BLIZZARD_API: 'API Battle.net',
  ADDON_COLLECTED: 'Addon',
  COMBAT_LOG: 'Log de combate',
  MANUAL: 'Manual',
  CALCULATED: 'Calculado',
  ESTIMATED: 'Estimado',
  UNAVAILABLE: 'No disponible',
};
