-- Protege a consulta pública por CPF com limite atômico por IP e fecha a RPC direta para anon.
-- A Edge Function usa service_role para consultar; o navegador deve passar somente pela Edge Function.

create table if not exists public.plantao_consulta_rate_limits (
  ip_hash text primary key check (ip_hash ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz not null,
  attempt_count integer not null check (attempt_count > 0),
  updated_at timestamptz not null
);

create index if not exists plantao_consulta_rate_limits_updated_at_idx
  on public.plantao_consulta_rate_limits (updated_at);

alter table public.plantao_consulta_rate_limits enable row level security;
revoke all on table public.plantao_consulta_rate_limits from public, anon, authenticated, service_role;

create or replace function public.consume_plantao_consulta_attempt(p_ip_hash text)
returns table(allowed boolean, retry_after_seconds integer)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_now timestamptz := pg_catalog.clock_timestamp();
  v_attempt_count integer;
  v_window_started_at timestamptz;
begin
  if p_ip_hash is null or p_ip_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'Identificador de consulta inválido.';
  end if;

  insert into public.plantao_consulta_rate_limits as rate
    (ip_hash, window_started_at, attempt_count, updated_at)
  values
    (p_ip_hash, v_now, 1, v_now)
  on conflict (ip_hash) do update
  set window_started_at = case
        when rate.window_started_at <= v_now - interval '15 minutes' then v_now
        else rate.window_started_at
      end,
      attempt_count = case
        when rate.window_started_at <= v_now - interval '15 minutes' then 1
        else rate.attempt_count + 1
      end,
      updated_at = v_now
  returning rate.attempt_count, rate.window_started_at
  into v_attempt_count, v_window_started_at;

  -- Limpeza limitada e oportunista de identificadores inativos; nenhum IP/CPF em claro é armazenado.
  if v_attempt_count = 1 then
    delete from public.plantao_consulta_rate_limits as stale
    where stale.ip_hash in (
      select old.ip_hash
      from public.plantao_consulta_rate_limits as old
      where old.updated_at < v_now - interval '1 day'
      order by old.updated_at
      limit 100
    );
  end if;

  return query
  select
    v_attempt_count <= 10,
    case
      when v_attempt_count <= 10 then 0
      else greatest(1, ceil(extract(epoch from (v_window_started_at + interval '15 minutes' - v_now)))::integer)
    end;
end;
$function$;

revoke all on function public.consume_plantao_consulta_attempt(text) from public, anon, authenticated;
grant execute on function public.consume_plantao_consulta_attempt(text) to service_role;

-- A consulta com dados pessoais só pode ser chamada pelo backend protegido com service_role.
revoke all on function public.consultar_resultado_plantao(text) from public, anon, authenticated;
grant execute on function public.consultar_resultado_plantao(text) to service_role;

comment on table public.plantao_consulta_rate_limits is
  'Contadores temporários por HMAC de IP para proteger a consulta pública do Plantão TO Saúde.';
