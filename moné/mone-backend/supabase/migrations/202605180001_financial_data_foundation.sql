-- Financial data foundation: Setu/AA integration state and raw evidence.
-- This migration intentionally avoids canonical transaction/category/nudge tables.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.aa_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  setu_consent_id text,
  setu_consent_url text,
  status text,
  vua text,
  mobile_number text,
  request_payload jsonb,
  response_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.aa_consents
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists setu_consent_id text,
  add column if not exists setu_consent_url text,
  add column if not exists status text,
  add column if not exists vua text,
  add column if not exists mobile_number text,
  add column if not exists request_payload jsonb,
  add column if not exists response_payload jsonb,
  add column if not exists requested_fi_types text[],
  add column if not exists requested_consent_types text[],
  add column if not exists last_webhook_status text,
  add column if not exists approved_at timestamptz,
  add column if not exists rejected_at timestamptz,
  add column if not exists revoked_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create index if not exists aa_consents_user_id_idx
  on public.aa_consents(user_id);

create index if not exists aa_consents_setu_consent_id_idx
  on public.aa_consents(setu_consent_id);

drop trigger if exists set_aa_consents_updated_at on public.aa_consents;
create trigger set_aa_consents_updated_at
before update on public.aa_consents
for each row
execute function public.set_updated_at();

create table if not exists public.aa_webhook_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  setu_consent_id text,
  setu_data_session_id text,
  event_type text,
  status text,
  payload jsonb,
  headers jsonb,
  received_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.aa_webhook_events
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists setu_consent_id text,
  add column if not exists setu_data_session_id text,
  add column if not exists event_type text,
  add column if not exists status text,
  add column if not exists payload jsonb,
  add column if not exists headers jsonb,
  add column if not exists received_at timestamptz not null default now(),
  add column if not exists created_at timestamptz not null default now();

create index if not exists aa_webhook_events_user_id_idx
  on public.aa_webhook_events(user_id);

create index if not exists aa_webhook_events_setu_consent_id_idx
  on public.aa_webhook_events(setu_consent_id);

create index if not exists aa_webhook_events_setu_data_session_id_idx
  on public.aa_webhook_events(setu_data_session_id);

create index if not exists aa_webhook_events_received_at_idx
  on public.aa_webhook_events(received_at desc);

create table if not exists public.aa_data_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  setu_consent_id text,
  setu_data_session_id text unique,
  status text not null default 'CREATED',
  request_payload jsonb,
  response_payload jsonb,
  error_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists aa_data_sessions_user_id_idx
  on public.aa_data_sessions(user_id);

create index if not exists aa_data_sessions_setu_consent_id_idx
  on public.aa_data_sessions(setu_consent_id);

drop trigger if exists set_aa_data_sessions_updated_at on public.aa_data_sessions;
create trigger set_aa_data_sessions_updated_at
before update on public.aa_data_sessions
for each row
execute function public.set_updated_at();

create table if not exists public.financial_data_artifacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  source text not null default 'SETU_AA',
  setu_consent_id text,
  setu_data_session_id text,
  fi_type text,
  fip_id text,
  artifact_kind text,
  schema_version text,
  payload jsonb not null,
  payload_hash text,
  received_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists financial_data_artifacts_user_id_idx
  on public.financial_data_artifacts(user_id);

create index if not exists financial_data_artifacts_consent_session_idx
  on public.financial_data_artifacts(setu_consent_id, setu_data_session_id);

create index if not exists financial_data_artifacts_payload_hash_idx
  on public.financial_data_artifacts(payload_hash);

create unique index if not exists financial_data_artifacts_idempotency_idx
  on public.financial_data_artifacts(
    source,
    coalesce(setu_data_session_id, ''),
    coalesce(artifact_kind, ''),
    payload_hash
  )
  where payload_hash is not null;

alter table public.aa_consents enable row level security;
alter table public.aa_webhook_events enable row level security;
alter table public.aa_data_sessions enable row level security;
alter table public.financial_data_artifacts enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'aa_consents'
      and policyname = 'Users can read own AA consents'
  ) then
    create policy "Users can read own AA consents"
      on public.aa_consents
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'aa_webhook_events'
      and policyname = 'Users can read own AA webhook events'
  ) then
    create policy "Users can read own AA webhook events"
      on public.aa_webhook_events
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'aa_data_sessions'
      and policyname = 'Users can read own AA data sessions'
  ) then
    create policy "Users can read own AA data sessions"
      on public.aa_data_sessions
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_data_artifacts'
      and policyname = 'Users can read own financial data artifacts'
  ) then
    create policy "Users can read own financial data artifacts"
      on public.financial_data_artifacts
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;
end;
$$;
