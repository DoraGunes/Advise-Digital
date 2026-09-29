-- Advise Digital V7/V8 PostgreSQL baseline
create table if not exists tenants (
  id text primary key, company_name text not null, plan text not null, active boolean not null default true,
  subscription_start timestamptz, subscription_end timestamptz, branding jsonb not null default '{}'::jsonb,
  notification_prefs jsonb not null default '{}'::jsonb, meta jsonb not null default '{}'::jsonb, created_at timestamptz default now()
);
create table if not exists users (
  id text primary key, tenant_id text references tenants(id), username text unique not null, password_hash text not null,
  role text not null, active boolean not null default true, full_name text, created_at timestamptz default now(), last_login_at timestamptz
);
create index if not exists idx_users_tenant on users(tenant_id);
create table if not exists audit_logs (id bigserial primary key, tenant_id text, type text, payload jsonb, created_at timestamptz default now());
create table if not exists licenses (id text primary key, code text unique not null, plan text not null, days integer not null, tenant_id text, status text not null, created_at timestamptz default now(), assigned_at timestamptz);
create table if not exists posts (id text primary key, tenant_id text not null, title text, caption text, link_url text, publish_status text, public_url text, created_at timestamptz default now());
create table if not exists tenant_settings (tenant_id text primary key, settings jsonb not null default '{}'::jsonb, updated_at timestamptz default now());
