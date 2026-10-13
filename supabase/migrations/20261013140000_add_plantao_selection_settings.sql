-- Configurações públicas da seleção Plantão TO Saúde.
-- Esta migração pertence exclusivamente ao repositório juniorxam/plantaotosaude.
create table if not exists public.plantao_configuracoes (
  id boolean primary key default true check (id = true),
  prazo_inscricao date not null default date '2026-10-16',
  data_resultado date,
  valores_cargos jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by text
);

insert into public.plantao_configuracoes (id, prazo_inscricao, data_resultado, valores_cargos)
values (true, date '2026-10-16', null, '{}'::jsonb)
on conflict (id) do nothing;

alter table public.plantao_configuracoes enable row level security;
revoke all on public.plantao_configuracoes from public;
revoke all on public.plantao_configuracoes from anon, authenticated;
grant select on public.plantao_configuracoes to anon, authenticated;
grant update on public.plantao_configuracoes to authenticated;

drop policy if exists "Configuração pública de plantões pode ser consultada" on public.plantao_configuracoes;
create policy "Configuração pública de plantões pode ser consultada"
on public.plantao_configuracoes for select to anon, authenticated using (true);

drop policy if exists "Administradores podem atualizar configuração de plantões" on public.plantao_configuracoes;
create policy "Administradores podem atualizar configuração de plantões"
on public.plantao_configuracoes for update to authenticated
using (
  exists (
    select 1 from public.admin_users a
    where a.ativo = true
      and lower(a.email) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  )
)
with check (
  exists (
    select 1 from public.admin_users a
    where a.ativo = true
      and lower(a.email) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  )
);

comment on table public.plantao_configuracoes is 'Configurações públicas da seleção Plantão TO Saúde: prazo, resultado e valores por cargo.';
