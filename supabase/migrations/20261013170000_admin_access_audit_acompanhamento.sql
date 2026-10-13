-- Plantão TO Saúde: permissões administrativas delegáveis, auditoria, unidade escalada e consulta dedicada.

alter table public.inscricoes
  add column if not exists unidade_escalada text;

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  actor_email text not null,
  action text not null,
  entity text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb
);
create index if not exists admin_audit_log_created_at_idx on public.admin_audit_log (created_at desc);
create index if not exists admin_audit_log_entity_idx on public.admin_audit_log (entity, entity_id);
alter table public.admin_audit_log enable row level security;
revoke all on public.admin_audit_log from public, anon;
revoke insert, update, delete, truncate, references, trigger on public.admin_audit_log from authenticated;
grant select on public.admin_audit_log to authenticated;
drop policy if exists "Administradores podem consultar auditoria" on public.admin_audit_log;
create policy "Administradores podem consultar auditoria" on public.admin_audit_log for select to authenticated using (
  exists (select 1 from public.admin_users a where a.ativo = true and lower(a.email) = lower(coalesce((select auth.jwt() ->> 'email'), '')))
);

create or replace function public.write_plantao_audit()
returns trigger language plpgsql security definer set search_path = ''
as $function$
declare
  actor text := lower(coalesce((select auth.jwt() ->> 'email'), 'sistema'));
  entity_id_value text;
  audit_details jsonb;
begin
  if tg_table_name = 'inscricoes' then
    entity_id_value := new.protocolo;
    audit_details := jsonb_build_object('status_anterior', old.status, 'status_novo', new.status, 'unidade_anterior', old.unidade_escalada, 'unidade_nova', new.unidade_escalada, 'nome', new.nome);
  elsif tg_table_name = 'plantao_configuracoes' then
    entity_id_value := 'true';
    audit_details := jsonb_build_object('prazo_anterior', old.prazo_inscricao, 'prazo_novo', new.prazo_inscricao, 'resultado_anterior', old.data_resultado, 'resultado_novo', new.data_resultado, 'valores_anteriores', old.valores_cargos, 'valores_novos', new.valores_cargos);
  end if;
  insert into public.admin_audit_log(actor_email, action, entity, entity_id, details) values (actor, tg_op, tg_table_name, entity_id_value, audit_details);
  return new;
end;
$function$;

drop trigger if exists audit_inscricoes_update on public.inscricoes;
create trigger audit_inscricoes_update after update on public.inscricoes for each row execute function public.write_plantao_audit();
drop trigger if exists audit_plantao_configuracoes_update on public.plantao_configuracoes;
create trigger audit_plantao_configuracoes_update after update on public.plantao_configuracoes for each row execute function public.write_plantao_audit();

create or replace function public.manage_admin_access(p_email text, p_ativo boolean)
returns table(email text, ativo boolean, created_at timestamptz)
language plpgsql security definer set search_path = ''
as $function$
declare
  actor text := lower(trim(coalesce((select auth.jwt() ->> 'email'), '')));
  normalized_email text := lower(trim(coalesce(p_email, '')));
  row_data public.admin_users%rowtype;
begin
  if not exists (select 1 from public.admin_users where ativo = true and lower(email) = actor) then raise exception using errcode = '42501', message = 'Apenas administradores ativos podem liberar acesso.'; end if;
  if normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception using errcode = '22023', message = 'Informe um e-mail válido.'; end if;
  if normalized_email = actor and p_ativo = false then raise exception using errcode = '22023', message = 'Você não pode remover o próprio acesso.'; end if;
  insert into public.admin_users(email, ativo) values (normalized_email, p_ativo) on conflict (email) do update set ativo = excluded.ativo returning * into row_data;
  insert into public.admin_audit_log(actor_email, action, entity, entity_id, details) values (actor, case when p_ativo then 'GRANT' else 'REVOKE' end, 'admin_users', normalized_email, jsonb_build_object('ativo', p_ativo));
  return query select row_data.email, row_data.ativo, row_data.created_at;
end;
$function$;
revoke all on function public.manage_admin_access(text, boolean) from public, anon;
grant execute on function public.manage_admin_access(text, boolean) to authenticated;

-- A RPC pública retorna apenas os dados necessários para o próprio candidato acompanhar a inscrição.
drop function if exists public.consultar_resultado_plantao(text);
create or replace function public.consultar_resultado_plantao(p_cpf text)
returns table(nome text, profissao text, registro text, protocolo text, status text, hospitais text[], unidade_escalada text, data_resultado date)
language sql security definer set search_path = ''
as $$
  select i.nome, i.profissao, i.registro, i.protocolo, i.status, i.hospitais, i.unidade_escalada, c.data_resultado
  from public.inscricoes i cross join public.plantao_configuracoes c
  where i.cpf = regexp_replace(coalesce(p_cpf,''), '\D', '', 'g') limit 1;
$$;
revoke all on function public.consultar_resultado_plantao(text) from public, authenticated;
grant execute on function public.consultar_resultado_plantao(text) to anon;

comment on table public.admin_audit_log is 'Registro de alterações administrativas no Plantão TO Saúde.';
