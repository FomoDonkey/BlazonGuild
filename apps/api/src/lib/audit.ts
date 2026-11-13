import { auditLogs, type Database } from '@blazonguild/database';

export interface AuditInput {
  actorUserId: string | null;
  guildId?: string | null;
  action: string;
  entity: string;
  entityId: string;
  changes?: unknown;
  ip?: string | null;
  userAgent?: string | null;
}

/** Append-only audit trail for every administrative or state-changing action. */
export async function audit(db: Database, input: AuditInput) {
  await db.insert(auditLogs).values({
    actorUserId: input.actorUserId,
    guildId: input.guildId ?? null,
    action: input.action,
    entity: input.entity,
    entityId: input.entityId,
    changes: input.changes ?? {},
    ip: input.ip ?? null,
    userAgent: input.userAgent?.slice(0, 300) ?? null,
  });
}
