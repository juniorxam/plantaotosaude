-- Currículo anexado às inscrições
alter table public.inscricoes add column if not exists curriculo_path text;

-- Bucket privado para documentos de candidatura
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'curriculos','curriculos',false,5242880,
  array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document']
)
on conflict (id) do update set
  public=false,
  file_size_limit=5242880,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Public curriculum uploads" on storage.objects;
create policy "Public curriculum uploads" on storage.objects for insert to anon
with check (bucket_id='curriculos' and name ~ '^curriculos/[0-9a-fA-F-]{36}\.(pdf|doc|docx)$');

drop policy if exists "Public curriculum upload metadata" on storage.objects;
create policy "Public curriculum upload metadata" on storage.objects for select to anon
using (bucket_id='curriculos' and name ~ '^curriculos/[0-9a-fA-F-]{36}\.(pdf|doc|docx)$');

drop policy if exists "Public curriculum cleanup" on storage.objects;
create policy "Public curriculum cleanup" on storage.objects for delete to anon
using (bucket_id='curriculos' and name ~ '^curriculos/[0-9a-fA-F-]{36}\.(pdf|doc|docx)$');

drop policy if exists "Admins can read curricula" on storage.objects;
create policy "Admins can read curricula" on storage.objects for select to authenticated
using (
  bucket_id='curriculos'
  and exists (
    select 1 from public.admin_users a
    where a.ativo=true
      and lower(a.email)=lower(coalesce((select auth.jwt()->>'email'),''))
  )
);

create or replace function public.register_plantao_inscricao(
  p_nome text, p_cpf text, p_nascimento date, p_telefone text, p_email text,
  p_profissao text, p_registro text, p_hospitais text[], p_plantoes text[],
  p_observacoes text default null, p_curriculo_path text default null
) returns table(protocolo text)
language plpgsql security definer set search_path = ''
as $function$
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
  if length(trim(coalesce(p_nome,''))) not between 5 and 150
     or length(regexp_replace(coalesce(p_cpf,''), '\D', '', 'g')) <> 11
     or p_nascimento is null or p_nascimento > current_date or p_nascimento < date '1900-01-01'
     or length(trim(coalesce(p_telefone,''))) not between 10 and 20
     or length(trim(coalesce(p_email,''))) not between 5 and 254
     or position('@' in p_email) < 2
     or length(trim(coalesce(p_profissao,''))) not between 2 and 100
     or length(trim(coalesce(p_registro,''))) not between 2 and 100
     or coalesce(array_length(p_hospitais,1),0) not between 1 and 6
     or coalesce(array_length(p_plantoes,1),0) not between 1 and 3
     or length(trim(coalesce(p_curriculo_path,''))) not between 10 and 300
     or p_curriculo_path !~ '^curriculos/[0-9a-fA-F-]{36}\.(pdf|doc|docx)$'
  then raise exception using errcode='22023',message='Dados da inscrição inválidos.'; end if;

  if exists(select 1 from unnest(p_hospitais) h where h is null or not(h=any(v_hospitais_permitidos)))
    then raise exception using errcode='22023',message='Hospital de interesse inválido.'; end if;
  if exists(select 1 from unnest(p_plantoes) p where p is null or not(p=any(v_plantoes_permitidos)))
    then raise exception using errcode='22023',message='Plantão selecionado inválido.'; end if;
  if exists(select 1 from unnest(p_hospitais) h group by h having count(*)>1)
    then raise exception using errcode='22023',message='Hospital repetido na inscrição.'; end if;
  if exists(select 1 from unnest(p_plantoes) p group by p having count(*)>1)
    then raise exception using errcode='22023',message='Plantão repetido na inscrição.'; end if;

  insert into public.inscricoes
    (nome,cpf,nascimento,telefone,email,profissao,registro,hospitais,plantoes,observacoes,curriculo_path,declaracao,status)
  values
    (trim(p_nome),regexp_replace(p_cpf,'\D','','g'),p_nascimento,trim(p_telefone),
     lower(trim(p_email)),trim(p_profissao),trim(p_registro),p_hospitais,p_plantoes,
     nullif(trim(coalesce(p_observacoes,'')),''),trim(p_curriculo_path),true,'pendente')
  returning public.inscricoes.protocolo into v_protocol;

  return query select v_protocol;
end;
$function$;

revoke execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text) from public,authenticated;
revoke execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text,text) from public,authenticated;
grant execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text,text[],text[],text,text) to anon;


-- O formulário pode remover somente o arquivo aleatório que acabou de enviar
-- quando a gravação da inscrição falhar. O caminho não contém dados pessoais.
