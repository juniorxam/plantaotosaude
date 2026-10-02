create or replace function public.register_plantao_inscricao(
  p_nome text, p_cpf text, p_nascimento date, p_telefone text, p_email text,
  p_profissao text, p_registro text, p_hospitais text[], p_plantoes text[], p_observacoes text default null
)
returns table (protocolo text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_protocol text;
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
  if length(trim(coalesce(p_nome, ''))) not between 5 and 150
     or length(regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g')) <> 11
     or p_nascimento is null or p_nascimento > current_date or p_nascimento < date '1900-01-01'
     or length(trim(coalesce(p_telefone, ''))) not between 10 and 20
     or length(trim(coalesce(p_email, ''))) not between 5 and 254
     or position('@' in p_email) < 2
     or length(trim(coalesce(p_profissao, ''))) not between 2 and 100
     or length(trim(coalesce(p_registro, ''))) not between 2 and 100
     or coalesce(array_length(p_hospitais, 1), 0) not between 1 and 6
     or coalesce(array_length(p_plantoes, 1), 0) not between 1 and 3
  then raise exception using errcode='22023', message='Dados da inscrição inválidos.'; end if;

  if exists (select 1 from unnest(p_hospitais) h where h is null or not (h = any(v_hospitais_permitidos)))
    then raise exception using errcode='22023', message='Hospital de interesse inválido.'; end if;
  if exists (select 1 from unnest(p_plantoes) p where p is null or not (p = any(v_plantoes_permitidos)))
    then raise exception using errcode='22023', message='Plantão selecionado inválido.'; end if;
  if exists (select 1 from unnest(p_hospitais) h group by h having count(*) > 1)
    then raise exception using errcode='22023', message='Hospital repetido na inscrição.'; end if;
  if exists (select 1 from unnest(p_plantoes) p group by p having count(*) > 1)
    then raise exception using errcode='22023', message='Plantão repetido na inscrição.'; end if;

  insert into public.inscricoes
    (nome, cpf, nascimento, telefone, email, profissao, registro, hospitais, plantoes, observacoes, declaracao, status)
  values
    (trim(p_nome), regexp_replace(p_cpf, '\D', '', 'g'), p_nascimento, trim(p_telefone),
     lower(trim(p_email)), trim(p_profissao), trim(p_registro), p_hospitais, p_plantoes,
     nullif(trim(coalesce(p_observacoes, '')), ''), true, 'pendente')
  returning public.inscricoes.protocolo into v_protocol;

  return query select v_protocol;
end;
$$;

revoke execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text) from public;
revoke execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text) from anon;
revoke execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text) from authenticated;
grant execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text) to anon;