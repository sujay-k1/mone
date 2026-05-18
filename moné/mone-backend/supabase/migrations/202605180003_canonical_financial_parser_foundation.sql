-- Canonical financial parser foundation.
-- This intentionally adds only account and transaction-like records.
-- Intelligence, categorisation, nudges, obligations, holdings-specific models,
-- and dashboard tables are deferred.

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

create table if not exists public.financial_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  source text not null default 'SETU_AA',
  setu_consent_id text,
  setu_data_session_id text,
  fip_id text,
  fi_type text not null,
  link_ref_number text,
  masked_account_number text,
  account_type text,
  account_status text,
  currency text,
  current_balance numeric,
  balance_datetime timestamptz,
  raw_profile jsonb,
  raw_summary jsonb,
  raw_account jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists financial_accounts_link_ref_unique_idx
  on public.financial_accounts(user_id, source, link_ref_number)
;

create index if not exists financial_accounts_user_id_idx
  on public.financial_accounts(user_id);

create index if not exists financial_accounts_session_idx
  on public.financial_accounts(setu_data_session_id);

create index if not exists financial_accounts_fi_type_idx
  on public.financial_accounts(fi_type);

drop trigger if exists set_financial_accounts_updated_at on public.financial_accounts;
create trigger set_financial_accounts_updated_at
before update on public.financial_accounts
for each row
execute function public.set_updated_at();

create table if not exists public.financial_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  financial_account_id uuid references public.financial_accounts(id) on delete cascade,
  source text not null default 'SETU_AA',
  setu_consent_id text,
  setu_data_session_id text,
  fip_id text,
  fi_type text,
  link_ref_number text,
  masked_account_number text,
  txn_id text,
  transaction_type text,
  direction text,
  mode text,
  amount numeric,
  narration text,
  reference text,
  value_date date,
  transaction_timestamp timestamptz,
  balance_after_transaction numeric,
  raw_transaction jsonb not null,
  raw_transaction_hash text,
  created_at timestamptz not null default now()
);

create unique index if not exists financial_transactions_txn_id_unique_idx
  on public.financial_transactions(user_id, source, fip_id, link_ref_number, txn_id)
;

create unique index if not exists financial_transactions_hash_unique_idx
  on public.financial_transactions(
    user_id,
    source,
    fip_id,
    coalesce(link_ref_number, ''),
    raw_transaction_hash
  )
  where txn_id is null and raw_transaction_hash is not null;

create index if not exists financial_transactions_user_id_idx
  on public.financial_transactions(user_id);

create index if not exists financial_transactions_account_id_idx
  on public.financial_transactions(financial_account_id);

create index if not exists financial_transactions_session_idx
  on public.financial_transactions(setu_data_session_id);

create index if not exists financial_transactions_timestamp_idx
  on public.financial_transactions(transaction_timestamp);

alter table public.financial_accounts enable row level security;
alter table public.financial_transactions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_accounts'
      and policyname = 'Users can read own financial accounts'
  ) then
    create policy "Users can read own financial accounts"
      on public.financial_accounts
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_transactions'
      and policyname = 'Users can read own financial transactions'
  ) then
    create policy "Users can read own financial transactions"
      on public.financial_transactions
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;
end;
$$;
