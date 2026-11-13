CREATE TABLE "activity_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"guild_id" uuid,
	"character_id" uuid,
	"type" text NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	"title" text NOT NULL,
	"detail" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"provenance" jsonb NOT NULL,
	"dedupe_key" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "api_tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"name" text NOT NULL,
	"token_hash" text NOT NULL,
	"scopes" jsonb DEFAULT '["ingest"]'::jsonb NOT NULL,
	"last_used_at" timestamp with time zone,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "audit_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"actor_user_id" uuid,
	"guild_id" uuid,
	"action" text NOT NULL,
	"entity" text NOT NULL,
	"entity_id" text NOT NULL,
	"changes" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"ip" text,
	"user_agent" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "character_equipment" (
	"character_id" uuid NOT NULL,
	"slot" text NOT NULL,
	"item_id" integer NOT NULL,
	"name" text NOT NULL,
	"quality" text NOT NULL,
	"item_level" integer,
	"enchantments" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"equipped_since" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "character_equipment_character_id_slot_pk" PRIMARY KEY("character_id","slot")
);
--> statement-breakpoint
CREATE TABLE "character_snapshots" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"character_id" uuid NOT NULL,
	"taken_at" timestamp with time zone DEFAULT now() NOT NULL,
	"checksum" text NOT NULL,
	"level" integer NOT NULL,
	"item_level" integer,
	"achievement_points" integer,
	"profile" jsonb NOT NULL,
	"equipment" jsonb,
	"statistics" jsonb,
	"specializations" jsonb,
	"professions" jsonb,
	"pvp" jsonb,
	"achievements" jsonb,
	"provenance" jsonb NOT NULL
);
--> statement-breakpoint
CREATE TABLE "characters" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"region" text NOT NULL,
	"slug" text NOT NULL,
	"blizzard_id" bigint,
	"name" text NOT NULL,
	"surname" text,
	"class_id" integer NOT NULL,
	"race_id" integer,
	"gender" text,
	"faction" text,
	"level" integer DEFAULT 1 NOT NULL,
	"guild_id" uuid,
	"guild_rank" integer,
	"average_item_level" integer,
	"equipped_item_level" integer,
	"achievement_points" integer,
	"honorable_kills" integer,
	"pvp_rank" integer,
	"last_login_at" timestamp with time zone,
	"talent_split" jsonb,
	"professions" jsonb,
	"primary_spec_id" integer,
	"avatar_url" text,
	"render_url" text,
	"owner_user_id" uuid,
	"ownership_verified" boolean DEFAULT false NOT NULL,
	"is_main" boolean DEFAULT false NOT NULL,
	"roster_seen_at" timestamp with time zone,
	"detail_synced_at" timestamp with time zone,
	"detail_checksum" text,
	"detail_state" text DEFAULT 'NEVER' NOT NULL,
	"detail_error" text,
	"last_viewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "encounter_metrics" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"raid_id" uuid,
	"character_id" uuid NOT NULL,
	"encounter_name" text NOT NULL,
	"result" text NOT NULL,
	"duration_ms" integer NOT NULL,
	"damage_done" bigint DEFAULT 0 NOT NULL,
	"healing_done" bigint DEFAULT 0 NOT NULL,
	"damage_taken" bigint DEFAULT 0 NOT NULL,
	"deaths" integer DEFAULT 0 NOT NULL,
	"active_time_pct" real,
	"provenance" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "guild_memberships" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"guild_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"role" text DEFAULT 'MEMBER' NOT NULL,
	"verified" boolean DEFAULT false NOT NULL,
	"source" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "guilds" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"region" text NOT NULL,
	"slug" text NOT NULL,
	"blizzard_id" bigint,
	"name" text NOT NULL,
	"faction" text NOT NULL,
	"ruleset_id" integer,
	"ruleset_name" text,
	"member_count" integer DEFAULT 0 NOT NULL,
	"achievement_points" integer,
	"crest" jsonb,
	"founded_at" timestamp with time zone,
	"settings" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"roster_checksum" text,
	"last_synced_at" timestamp with time zone,
	"sync_state" text DEFAULT 'NEVER' NOT NULL,
	"sync_error" text,
	"last_viewed_at" timestamp with time zone,
	"tracked_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ingest_batches" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"source" text NOT NULL,
	"checksum" text NOT NULL,
	"addon_version" text,
	"client_build" text,
	"payload" jsonb NOT NULL,
	"status" text DEFAULT 'RECEIVED' NOT NULL,
	"error" text,
	"received_at" timestamp with time zone DEFAULT now() NOT NULL,
	"processed_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "items" (
	"id" integer PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"quality" text NOT NULL,
	"icon_url" text,
	"media_fetched_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"guild_id" uuid,
	"type" text NOT NULL,
	"title" text NOT NULL,
	"body" text,
	"link" text,
	"read_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "raid_signups" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"raid_id" uuid NOT NULL,
	"character_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"status" text NOT NULL,
	"role" text NOT NULL,
	"comment" text,
	"group_no" integer,
	"slot" integer,
	"signed_up_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "raids" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"guild_id" uuid NOT NULL,
	"title" text NOT NULL,
	"instance_key" text NOT NULL,
	"starts_at" timestamp with time zone NOT NULL,
	"ends_at" timestamp with time zone,
	"status" text DEFAULT 'SCHEDULED' NOT NULL,
	"capacity" integer DEFAULT 40 NOT NULL,
	"min_level" integer,
	"notes" text,
	"leader_user_id" uuid,
	"created_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "sessions" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"last_seen_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ip" text,
	"user_agent" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "static_cache" (
	"key" text PRIMARY KEY NOT NULL,
	"namespace" text,
	"payload" jsonb,
	"fetched_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "sync_jobs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"kind" text NOT NULL,
	"region" text NOT NULL,
	"target" text NOT NULL,
	"guild_id" uuid,
	"state" text DEFAULT 'QUEUED' NOT NULL,
	"trigger" text NOT NULL,
	"requested_by_user_id" uuid,
	"stats" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"error" text,
	"started_at" timestamp with time zone,
	"finished_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" text NOT NULL,
	"password_hash" text,
	"display_name" text NOT NULL,
	"platform_role" text DEFAULT 'USER' NOT NULL,
	"battlenet_id" bigint,
	"battle_tag" text,
	"is_active" boolean DEFAULT true NOT NULL,
	"last_login_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activity_events" ADD CONSTRAINT "activity_events_character_id_characters_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."characters"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "api_tokens" ADD CONSTRAINT "api_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actor_user_id_users_id_fk" FOREIGN KEY ("actor_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "character_equipment" ADD CONSTRAINT "character_equipment_character_id_characters_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."characters"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "character_snapshots" ADD CONSTRAINT "character_snapshots_character_id_characters_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."characters"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "characters" ADD CONSTRAINT "characters_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "characters" ADD CONSTRAINT "characters_owner_user_id_users_id_fk" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "encounter_metrics" ADD CONSTRAINT "encounter_metrics_raid_id_raids_id_fk" FOREIGN KEY ("raid_id") REFERENCES "public"."raids"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "encounter_metrics" ADD CONSTRAINT "encounter_metrics_character_id_characters_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."characters"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_memberships" ADD CONSTRAINT "guild_memberships_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_memberships" ADD CONSTRAINT "guild_memberships_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guilds" ADD CONSTRAINT "guilds_tracked_by_user_id_users_id_fk" FOREIGN KEY ("tracked_by_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ingest_batches" ADD CONSTRAINT "ingest_batches_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "raid_signups" ADD CONSTRAINT "raid_signups_raid_id_raids_id_fk" FOREIGN KEY ("raid_id") REFERENCES "public"."raids"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "raid_signups" ADD CONSTRAINT "raid_signups_character_id_characters_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."characters"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "raid_signups" ADD CONSTRAINT "raid_signups_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "raids" ADD CONSTRAINT "raids_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "raids" ADD CONSTRAINT "raids_leader_user_id_users_id_fk" FOREIGN KEY ("leader_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "raids" ADD CONSTRAINT "raids_created_by_user_id_users_id_fk" FOREIGN KEY ("created_by_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sync_jobs" ADD CONSTRAINT "sync_jobs_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sync_jobs" ADD CONSTRAINT "sync_jobs_requested_by_user_id_users_id_fk" FOREIGN KEY ("requested_by_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "activity_dedupe_uq" ON "activity_events" USING btree ("dedupe_key");--> statement-breakpoint
CREATE INDEX "activity_guild_time_idx" ON "activity_events" USING btree ("guild_id","occurred_at");--> statement-breakpoint
CREATE INDEX "activity_character_time_idx" ON "activity_events" USING btree ("character_id","occurred_at");--> statement-breakpoint
CREATE UNIQUE INDEX "api_tokens_hash_uq" ON "api_tokens" USING btree ("token_hash");--> statement-breakpoint
CREATE INDEX "api_tokens_user_idx" ON "api_tokens" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "audit_created_idx" ON "audit_logs" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "audit_guild_idx" ON "audit_logs" USING btree ("guild_id","created_at");--> statement-breakpoint
CREATE INDEX "equipment_item_idx" ON "character_equipment" USING btree ("item_id");--> statement-breakpoint
CREATE INDEX "snapshots_character_taken_idx" ON "character_snapshots" USING btree ("character_id","taken_at");--> statement-breakpoint
CREATE UNIQUE INDEX "snapshots_character_checksum_uq" ON "character_snapshots" USING btree ("character_id","checksum");--> statement-breakpoint
CREATE UNIQUE INDEX "characters_region_slug_uq" ON "characters" USING btree ("region","slug");--> statement-breakpoint
CREATE INDEX "characters_guild_idx" ON "characters" USING btree ("guild_id");--> statement-breakpoint
CREATE INDEX "characters_owner_idx" ON "characters" USING btree ("owner_user_id");--> statement-breakpoint
CREATE INDEX "characters_class_idx" ON "characters" USING btree ("class_id");--> statement-breakpoint
CREATE INDEX "characters_name_idx" ON "characters" USING btree ("name");--> statement-breakpoint
CREATE INDEX "encounter_metrics_character_idx" ON "encounter_metrics" USING btree ("character_id");--> statement-breakpoint
CREATE UNIQUE INDEX "memberships_guild_user_uq" ON "guild_memberships" USING btree ("guild_id","user_id");--> statement-breakpoint
CREATE INDEX "memberships_user_idx" ON "guild_memberships" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "guilds_region_slug_uq" ON "guilds" USING btree ("region","slug");--> statement-breakpoint
CREATE UNIQUE INDEX "guilds_region_blizzard_uq" ON "guilds" USING btree ("region","blizzard_id");--> statement-breakpoint
CREATE INDEX "guilds_name_idx" ON "guilds" USING btree ("name");--> statement-breakpoint
CREATE UNIQUE INDEX "ingest_checksum_uq" ON "ingest_batches" USING btree ("checksum");--> statement-breakpoint
CREATE INDEX "ingest_user_idx" ON "ingest_batches" USING btree ("user_id","received_at");--> statement-breakpoint
CREATE INDEX "notifications_user_idx" ON "notifications" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "signups_raid_character_uq" ON "raid_signups" USING btree ("raid_id","character_id");--> statement-breakpoint
CREATE UNIQUE INDEX "signups_raid_user_uq" ON "raid_signups" USING btree ("raid_id","user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "signups_raid_position_uq" ON "raid_signups" USING btree ("raid_id","group_no","slot");--> statement-breakpoint
CREATE INDEX "raids_guild_start_idx" ON "raids" USING btree ("guild_id","starts_at");--> statement-breakpoint
CREATE INDEX "sessions_user_idx" ON "sessions" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "sessions_expiry_idx" ON "sessions" USING btree ("expires_at");--> statement-breakpoint
CREATE INDEX "sync_jobs_created_idx" ON "sync_jobs" USING btree ("created_at");--> statement-breakpoint
CREATE INDEX "sync_jobs_target_idx" ON "sync_jobs" USING btree ("region","target");--> statement-breakpoint
CREATE UNIQUE INDEX "users_email_uq" ON "users" USING btree ("email");--> statement-breakpoint
CREATE UNIQUE INDEX "users_battlenet_uq" ON "users" USING btree ("battlenet_id");