-- Harden public registration access.
-- Anonymous visitors can only submit; authenticated access is restricted by RLS to active admins.

revoke all on table public.inscricoes from anon, authenticated;
grant insert on table public.inscricoes to anon;
grant select, update on table public.inscricoes to authenticated;

drop policy if exists "Admins podem consultar inscricoes" on public.inscricoes;
create policy "Admins podem consultar inscricoes"
on public.inscricoes
for select
to authenticated
using (
  exists (
    select 1
    from public.admin_users a
    where a.ativo = true
      and lower(a.email) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  )
);

drop policy if exists "Admins podem atualizar inscricoes" on public.inscricoes;
create policy "Admins podem atualizar inscricoes"
on public.inscricoes
for update
to authenticated
using (
  exists (
    select 1
    from public.admin_users a
    where a.ativo = true
      and lower(a.email) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  )
)
with check (
  status = any (array['pendente','confirmado','escalado','recusado'])
);
