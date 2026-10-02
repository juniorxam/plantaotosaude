-- Registra se o profissional já é servidor do Estado.
alter table public.inscricoes add column if not exists servidor_estado boolean;

-- A função atualizada exige a resposta e mantém o registro protegido por service_role.
drop function if exists public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text,text);
drop function if exists public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text);

create or replace function public.register_plantao_inscricao(
  p_nome text, p_cpf text, p_nascimento date, p_telefone text, p_email text,
  p_profissao text, p_registro text, p_hospitais text[], p_plantoes text[],
  p_servidor_estado boolean, p_observacoes text default null, p_curriculo_path text default null
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
    'A — Véspera, noturno — 31/10/2026, 19h às 7h de 01/11',
    'B — Dia do concurso, diurno — 01/11/2026, 7h às 19h',
    'C — Dia do concurso, noturno — 01/11/2026, 19h às 7h de 02/11'
  ];
begin
  if length(trim(coalesce(p_nome,''))) not between 5 and 150
     or length(v_cpf) <> 11
     or p_nascimento is null or p_nascimento > current_date or p_nascimento < date '1900-01-01'
     or length(trim(coalesce(p_telefone,''))) not between 10 and 20
     or length(trim(coalesce(p_email,''))) not between 5 and 254
     or position('@' in p_email) < 2
     or length(trim(coalesce(p_profissao,''))) not between 2 and 100
     or length(trim(coalesce(p_registro,''))) not between 2 and 100
     or p_servidor_estado is null
     or coalesce(array_length(p_hospitais,1),0) not between 1 and 6
     or coalesce(array_length(p_plantoes,1),0) not between 1 and 3
     or length(trim(coalesce(p_curriculo_path,''))) not between 10 and 300
     or p_curriculo_path !~ '^curriculos/[0-9a-fA-F-]{36}\.(pdf|doc|docx)$'
  then raise exception using errcode='22023',message='Dados da inscrição inválidos.'; end if;
  if exists(select 1 from unnest(p_hospitais) h where h is null or not(h=any(v_hospitais_permitidos))) then raise exception using errcode='22023',message='Hospital de interesse inválido.'; end if;
  if exists(select 1 from unnest(p_plantoes) p where p is null or not(p=any(v_plantoes_permitidos))) then raise exception using errcode='22023',message='Plantão selecionado inválido.'; end if;
  if exists(select 1 from unnest(p_hospitais) h group by h having count(*)>1) then raise exception using errcode='22023',message='Hospital repetido na inscrição.'; end if;
  if exists(select 1 from unnest(p_plantoes) p group by p having count(*)>1) then raise exception using errcode='22023',message='Plantão repetido na inscrição.'; end if;
  if exists(select 1 from public.inscricoes where cpf = v_cpf) then raise exception using errcode='23505',message='Já existe uma inscrição para este CPF.'; end if;
  insert into public.inscricoes
    (nome,cpf,nascimento,telefone,email,profissao,registro,hospitais,plantoes,servidor_estado,observacoes,curriculo_path,declaracao,status)
  values
    (trim(p_nome),v_cpf,p_nascimento,trim(p_telefone),lower(trim(p_email)),trim(p_profissao),trim(p_registro),p_hospitais,p_plantoes,p_servidor_estado,nullif(trim(coalesce(p_observacoes,'')),''),trim(p_curriculo_path),true,'pendente')
  returning public.inscricoes.protocolo into v_protocol;
  return query select v_protocol;
end;
$function$;

revoke all on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],boolean,text,text) from public, anon, authenticated;
grant execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],boolean,text,text) to service_role;
