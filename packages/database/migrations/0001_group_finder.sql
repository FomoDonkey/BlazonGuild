CREATE TABLE "group_listings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"guild_id" uuid NOT NULL,
	"dungeon_key" text NOT NULL,
	"note" text,
	"starts_at" timestamp with time zone,
	"leader_user_id" uuid NOT NULL,
	"status" text DEFAULT 'OPEN' NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "group_members" (
	"listing_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"character_id" uuid NOT NULL,
	"role" text NOT NULL,
	"joined_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "group_members_listing_id_user_id_pk" PRIMARY KEY("listing_id","user_id")
);
--> statement-breakpoint
ALTER TABLE "group_listings" ADD CONSTRAINT "group_listings_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "group_listings" ADD CONSTRAINT "group_listings_leader_user_id_users_id_fk" FOREIGN KEY ("leader_user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_listing_id_group_listings_id_fk" FOREIGN KEY ("listing_id") REFERENCES "public"."group_listings"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_character_id_characters_id_fk" FOREIGN KEY ("character_id") REFERENCES "public"."characters"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "group_listings_guild_idx" ON "group_listings" USING btree ("guild_id","status","expires_at");--> statement-breakpoint
CREATE INDEX "group_members_character_idx" ON "group_members" USING btree ("character_id");