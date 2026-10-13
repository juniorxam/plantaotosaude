-- Plantão TO Saúde: escala 31/10–02/11/2026, elegibilidade 18+ e designação final segura.
-- Valores de 12h e 24h são configurados separadamente; nenhum múltiplo é presumido.

alter table public.inscricoes
  add column if not exists plantao_escalado text,
  add column if not exists valor_pagamento numeric(10,2);

alter table public.plantao_configuracoes
  add column if not exists valores_cargos_24h jsonb not null default '{}'::jsonb;

do $block$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conname = 'inscricoes_valor_pagamento_nonnegative'
      and conrelid = 'public.inscricoes'::pg_catalog.regclass
  ) then
    alter table public.inscricoes
      add constraint inscricoes_valor_pagamento_nonnegative
      check (valor_pagamento is null or valor_pagamento >= 0);
  end if;
end;
$block$;

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
    audit_details := jsonb_build_object(
      'status_anterior', old.status,
      'status_novo', new.status,
      'unidade_anterior', old.unidade_escalada,
      'unidade_nova', new.unidade_escalada,
      'plantao_escalado_anterior', old.plantao_escalado,
      'plantao_escalado_novo', new.plantao_escalado,
      'valor_pagamento_anterior', old.valor_pagamento,
      'valor_pagamento_novo', new.valor_pagamento,
      'plantoes_preferidos_anteriores', old.plantoes,
      'plantoes_preferidos_novos', new.plantoes,
      'nome', new.nome
    );
  elsif tg_table_name = 'plantao_configuracoes' then
    entity_id_value := 'true';
    audit_details := jsonb_build_object(
      'prazo_anterior', old.prazo_inscricao,
      'prazo_novo', new.prazo_inscricao,
      'resultado_anterior', old.data_resultado,
      'resultado_novo', new.data_resultado,
      'valores_12h_anteriores', old.valores_cargos,
      'valores_12h_novos', new.valores_cargos,
      'valores_24h_anteriores', old.valores_cargos_24h,
      'valores_24h_novos', new.valores_cargos_24h
    );
  end if;
  insert into public.admin_audit_log(actor_email, action, entity, entity_id, details)
  values (actor, tg_op, tg_table_name, entity_id_value, audit_details);
  return new;
end;
$function$;

-- Converte preferências históricas A/B/C para as mesmas janelas de 12h, sem alterar a disponibilidade escolhida.
update public.inscricoes as i
set plantoes = array(
  select case p.value
    when 'A — Véspera, noturno — 31/10/2026, 19h às 7h de 01/11' then '31/10/2026 · 19h às 01/11/2026 07h (12h)'
    when 'B — Dia do concurso, diurno — 01/11/2026, 7h às 19h' then '01/11/2026 · 07h às 19h (12h)'
    when 'C — Dia do concurso, noturno — 01/11/2026, 19h às 7h de 02/11' then '01/11/2026 · 19h às 02/11/2026 07h (12h)'
    else p.value
  end
  from unnest(i.plantoes) with ordinality as p(value, ord)
  order by p.ord
)
where i.plantoes && array[
  'A — Véspera, noturno — 31/10/2026, 19h às 7h de 01/11',
  'B — Dia do concurso, diurno — 01/11/2026, 7h às 19h',
  'C — Dia do concurso, noturno — 01/11/2026, 19h às 7h de 02/11'
];

create or replace function public.register_plantao_inscricao(
  p_nome text, p_cpf text, p_nascimento date, p_telefone text, p_email text,
  p_profissao text, p_registro text, p_hospitais text[], p_plantoes text[],
  p_servidor_estado boolean, p_orgao_lotacao text, p_setor_lotacao text,
  p_observacoes text default null, p_curriculo_path text default null
) returns table(protocolo text)
language plpgsql security definer set search_path = ''
as $function$
declare
  v_protocol text;
  v_cpf text := regexp_replace(coalesce(p_cpf,''), '\D', '', 'g');
  v_hospitais_permitidos text[] := array[
    'Palmas — Hospital Geral de Palmas','Araguaína — Hospital Regional de Araguaína',
    'Gurupi — Hospital Regional de Gurupi','Paraíso do Tocantins — Hospital Regional de Paraíso',
    'Porto Nacional — Hospital Regional de Porto Nacional','Augustinópolis — Hospital Regional de Augustinópolis'
  ];
  v_plantoes_permitidos text[] := array[
    '31/10/2026 · 07h às 19h (12h)',
    '31/10/2026 · 07h às 01/11/2026 07h (24h)',
    '31/10/2026 · 19h às 01/11/2026 07h (12h)',
    '31/10/2026 · 19h às 01/11/2026 19h (24h)',
    '01/11/2026 · 07h às 19h (12h)',
    '01/11/2026 · 07h às 02/11/2026 07h (24h)',
    '01/11/2026 · 19h às 02/11/2026 07h (12h)',
    '01/11/2026 · 19h às 02/11/2026 19h (24h)',
    '02/11/2026 · 07h às 19h (12h)',
    '02/11/2026 · 07h às 03/11/2026 07h (24h)',
    'A — Véspera, noturno — 31/10/2026, 19h às 7h de 01/11',
    'B — Dia do concurso, diurno — 01/11/2026, 7h às 19h',
    'C — Dia do concurso, noturno — 01/11/2026, 19h às 7h de 02/11'
  ];
  v_plantoes_normalizados text[];
begin
  if length(trim(coalesce(p_nome,''))) not between 5 and 150
     or length(v_cpf) <> 11
     or p_nascimento is null or p_nascimento < date '1900-01-01' or p_nascimento > date '2008-10-31'
     or length(trim(coalesce(p_telefone,''))) not between 10 and 20
     or length(trim(coalesce(p_email,''))) not between 5 and 254
     or position('@' in p_email) < 2
     or length(trim(coalesce(p_profissao,''))) not between 2 and 100
     or length(trim(coalesce(p_registro,''))) not between 2 and 100
     or p_servidor_estado is null
     or (p_servidor_estado = false and length(trim(coalesce(p_orgao_lotacao,''))) not between 2 and 150)
     or (p_servidor_estado = true and length(trim(coalesce(p_setor_lotacao,''))) not between 2 and 150)
     or coalesce(array_length(p_hospitais,1),0) not between 1 and 6
     or coalesce(array_length(p_plantoes,1),0) not between 1 and 3
     or length(trim(coalesce(p_curriculo_path,''))) not between 10 and 300
     or p_curriculo_path !~ '^curriculos/[0-9a-fA-F-]{36}\.(pdf|doc|docx)$'
  then raise exception using errcode='22023',message='Dados da inscrição inválidos. Verifique se terá 18 anos completos até 31/10/2026.'; end if;
  if exists(select 1 from unnest(p_hospitais) h where h is null or not(h=any(v_hospitais_permitidos))) then raise exception using errcode='22023',message='Hospital de interesse inválido.'; end if;
  if exists(select 1 from unnest(p_plantoes) p where p is null or not(p=any(v_plantoes_permitidos))) then raise exception using errcode='22023',message='Plantão selecionado inválido.'; end if;
  if exists(select 1 from unnest(p_hospitais) h group by h having count(*)>1) then raise exception using errcode='22023',message='Hospital repetido na inscrição.'; end if;
  if exists(select 1 from unnest(p_plantoes) p group by p having count(*)>1) then raise exception using errcode='22023',message='Plantão repetido na inscrição.'; end if;
  if exists(select 1 from public.inscricoes where cpf = v_cpf) then raise exception using errcode='23505',message='Já existe uma inscrição para este CPF.'; end if;

  select array_agg(case p.value
    when 'A — Véspera, noturno — 31/10/2026, 19h às 7h de 01/11' then '31/10/2026 · 19h às 01/11/2026 07h (12h)'
    when 'B — Dia do concurso, diurno — 01/11/2026, 7h às 19h' then '01/11/2026 · 07h às 19h (12h)'
    when 'C — Dia do concurso, noturno — 01/11/2026, 19h às 7h de 02/11' then '01/11/2026 · 19h às 02/11/2026 07h (12h)'
    else p.value end order by p.ord)
  into v_plantoes_normalizados
  from unnest(p_plantoes) with ordinality as p(value, ord);

  insert into public.inscricoes
    (nome,cpf,nascimento,telefone,email,profissao,registro,hospitais,plantoes,servidor_estado,orgao_lotacao,setor_lotacao,observacoes,curriculo_path,declaracao,status)
  values
    (trim(p_nome),v_cpf,p_nascimento,trim(p_telefone),lower(trim(p_email)),trim(p_profissao),trim(p_registro),p_hospitais,v_plantoes_normalizados,p_servidor_estado,
     nullif(trim(coalesce(p_orgao_lotacao,'')),''),nullif(trim(coalesce(p_setor_lotacao,'')),''),nullif(trim(coalesce(p_observacoes,'')),''),trim(p_curriculo_path),true,'pendente')
  returning public.inscricoes.protocolo into v_protocol;
  return query select v_protocol;
end;
$function$;
revoke all on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],boolean,text,text,text,text) from public, anon, authenticated;
grant execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],boolean,text,text,text,text) to service_role;

-- Consulta pública continua com campos mínimos; nunca retorna CPF, telefone, e-mail ou currículo.
drop function if exists public.consultar_resultado_plantao(text);
create function public.consultar_resultado_plantao(p_cpf text)
returns table(
  nome text, profissao text, registro text, protocolo text, status text,
  hospitais text[], unidade_escalada text, plantao_escalado text,
  valor_pagamento numeric, data_resultado date
)
language sql security definer set search_path = ''
as $function$
  select i.nome, i.profissao, i.registro, i.protocolo, i.status,
         i.hospitais, i.unidade_escalada, i.plantao_escalado,
         i.valor_pagamento, c.data_resultado
  from public.inscricoes as i
  cross join public.plantao_configuracoes as c
  where i.cpf = regexp_replace(coalesce(p_cpf,''), '\D', '', 'g')
  limit 1;
$function$;
revoke all on function public.consultar_resultado_plantao(text) from public, anon, authenticated;
grant execute on function public.consultar_resultado_plantao(text) to service_role;

create or replace function public.set_plantao_assignment(
  p_inscricao_id uuid,
  p_status text,
  p_unidade_escalada text default null,
  p_plantao_escalado text default null
) returns table(status text, unidade_escalada text, plantao_escalado text, valor_pagamento numeric)
language plpgsql security definer set search_path = ''
as $function$
declare
  v_actor text := lower(trim(coalesce((select auth.jwt() ->> 'email'),'')));
  v_registration public.inscricoes%rowtype;
  v_unit text := nullif(trim(coalesce(p_unidade_escalada,'')), '');
  v_shift text := nullif(trim(coalesce(p_plantao_escalado,'')), '');
  v_payment numeric(10,2);
  v_raw_amount text;
  v_settings public.plantao_configuracoes%rowtype;
begin
  if not exists (select 1 from public.admin_users where ativo = true and lower(email) = v_actor) then
    raise exception using errcode = '42501', message = 'Apenas administradores ativos podem organizar a escala.';
  end if;
  if p_status is null or p_status not in ('pendente','confirmado','escalado','recusado') then
    raise exception using errcode = '22023', message = 'Status inválido.';
  end if;
  select i.* into v_registration
  from public.inscricoes as i
  where i.id = p_inscricao_id
  for update;
  if not found then raise exception using errcode = 'P0002', message = 'Inscrição não encontrada.'; end if;

  if p_status in ('pendente','recusado') then
    v_unit := null;
    v_shift := null;
    v_payment := null;
  else
    if (v_unit is null) <> (v_shift is null) then
      raise exception using errcode = '22023', message = 'Selecione hospital e plantão juntos, ou deixe os dois em branco.';
    end if;
    if p_status = 'escalado' and (v_unit is null or v_shift is null) then
      raise exception using errcode = '22023', message = 'Para marcar como escalado, informe o hospital e o plantão.';
    end if;
    if v_unit is not null then
      if not (v_unit = any(v_registration.hospitais) or v_unit = v_registration.unidade_escalada) then
        raise exception using errcode = '22023', message = 'O hospital deve estar entre as preferências indicadas pelo profissional.';
      end if;
      if not (v_shift = any(v_registration.plantoes)) then
        raise exception using errcode = '22023', message = 'O plantão deve estar entre as preferências indicadas pelo profissional.';
      end if;
      if right(v_shift, 5) not in ('(12h)','(24h)') then
        raise exception using errcode = '22023', message = 'A duração do plantão não foi reconhecida.';
      end if;
      select c.* into v_settings from public.plantao_configuracoes as c where c.id = true;
      v_raw_amount := case
        when right(v_shift,5) = '(12h)' then v_settings.valores_cargos ->> v_registration.profissao
        else v_settings.valores_cargos_24h ->> v_registration.profissao
      end;
      if v_raw_amount is not null and btrim(v_raw_amount) <> '' then
        begin
          v_payment := round(v_raw_amount::numeric, 2);
        exception when invalid_text_representation then
          raise exception using errcode = '22023', message = 'Configure um valor numérico válido para este cargo e duração.';
        end;
      end if;
      if p_status = 'escalado' and v_payment is null then
        raise exception using errcode = '22023', message = 'Configure o valor para este cargo e duração antes de marcar como escalado.';
      end if;
    end if;
  end if;

  update public.inscricoes as i
  set status = p_status,
      unidade_escalada = v_unit,
      plantao_escalado = v_shift,
      valor_pagamento = v_payment,
      updated_at = pg_catalog.now()
  where i.id = p_inscricao_id;
  return query select p_status, v_unit, v_shift, v_payment;
end;
$function$;
revoke all on function public.set_plantao_assignment(uuid,text,text,text) from public, anon;
grant execute on function public.set_plantao_assignment(uuid,text,text,text) to authenticated;

comment on column public.inscricoes.plantao_escalado is 'Plantão final designado pela gestão dentre as preferências do profissional.';
comment on column public.inscricoes.valor_pagamento is 'Valor congelado para a designação, conforme cargo e duração configurados.';
comment on column public.plantao_configuracoes.valores_cargos_24h is 'Valores explícitos por cargo para turnos de 24 horas; não inferidos dos valores de 12h.';
