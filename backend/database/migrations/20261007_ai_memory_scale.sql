-- AdVise memory/learning scale preparation
-- ADDITIVE + IDEMPOTENT ONLY.
-- This file is intentionally NOT executed automatically by the application.
-- Existing JSON runtime stores remain supported until a controlled migration is approved.

create table if not exists content_memories (
  id text primary key,
  tenant_id text not null references tenants(id) on delete cascade,
  account_id text,
  post_id text,
  source_model text,
  sector text,
  product_name text,
  product_category text,
  media_type text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  original_output jsonb not null default '{}'::jsonb,
  final_output jsonb,
  style_recipe jsonb not null default '{}'::jsonb,
  performance_summary jsonb,
  user_edit_distance double precision,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists performance_memories (
  id text primary key,
  tenant_id text not null references tenants(id) on delete cascade,
  mode text not null,
  provider text,
  provider_status text,
  timestamp timestamptz,
  measured_at timestamptz,
  placement text,
  media_type text,
  creative_type text,
  post_id text,
  campaign_id text,
  adset_id text,
  ad_id text,
  sample_size integer not null default 1,
  confidence jsonb not null default '{}'::jsonb,
  freshness jsonb not null default '{}'::jsonb,
  time_range jsonb not null default '{}'::jsonb,
  metrics jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists style_recipes (
  id text primary key,
  tenant_id text not null references tenants(id) on delete cascade,
  sector text,
  media_type text,
  recipe jsonb not null default '{}'::jsonb,
  sample_size integer not null default 0,
  confidence double precision,
  rationale text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists ai_generation_events (
  id text primary key,
  tenant_id text not null references tenants(id) on delete cascade,
  generation_id text,
  source text,
  model text,
  request_type text,
  correlation_id text,
  quality jsonb not null default '{}'::jsonb,
  decision_meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists publish_outcomes (
  id text primary key,
  tenant_id text not null references tenants(id) on delete cascade,
  generation_id text,
  post_id text,
  campaign_id text,
  adset_id text,
  ad_id text,
  mode text not null,
  published_at timestamptz,
  measured_at timestamptz,
  score double precision,
  metrics jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_content_memories_tenant_created
  on content_memories(tenant_id, created_at desc);
create index if not exists idx_content_memories_tenant_sector
  on content_memories(tenant_id, sector);
create index if not exists idx_content_memories_tenant_media
  on content_memories(tenant_id, media_type);
create index if not exists idx_content_memories_tenant_published
  on content_memories(tenant_id, published_at desc);

create index if not exists idx_performance_memories_tenant_measured
  on performance_memories(tenant_id, measured_at desc);
create index if not exists idx_performance_memories_tenant_mode_media
  on performance_memories(tenant_id, mode, media_type);
create index if not exists idx_performance_memories_tenant_campaign
  on performance_memories(tenant_id, campaign_id);
create index if not exists idx_performance_memories_tenant_ad
  on performance_memories(tenant_id, ad_id);

create index if not exists idx_style_recipes_tenant_updated
  on style_recipes(tenant_id, updated_at desc);
create index if not exists idx_style_recipes_tenant_sector_media
  on style_recipes(tenant_id, sector, media_type);

create index if not exists idx_ai_generation_events_tenant_created
  on ai_generation_events(tenant_id, created_at desc);
create index if not exists idx_ai_generation_events_tenant_generation
  on ai_generation_events(tenant_id, generation_id);

create index if not exists idx_publish_outcomes_tenant_measured
  on publish_outcomes(tenant_id, measured_at desc);
create index if not exists idx_publish_outcomes_tenant_post
  on publish_outcomes(tenant_id, post_id);
create index if not exists idx_publish_outcomes_tenant_ad
  on publish_outcomes(tenant_id, ad_id);
