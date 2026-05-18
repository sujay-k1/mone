-- Ensure Setu callback persistence can write webhook status in all environments.
-- Production was manually patched with this column after setu-aa-callback deploy.

alter table public.aa_webhook_events
  add column if not exists status text;

notify pgrst, 'reload schema';
