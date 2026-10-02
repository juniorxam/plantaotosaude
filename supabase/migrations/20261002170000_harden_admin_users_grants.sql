-- Remove public table privileges from the admin allowlist table.
-- Authenticated users only need SELECT so the inscricoes RLS policy can verify active admins.
revoke all on table public.admin_users from public;
revoke all on table public.admin_users from anon;
revoke insert, update, delete, truncate, references, trigger on table public.admin_users from authenticated;
grant select on table public.admin_users to authenticated;
