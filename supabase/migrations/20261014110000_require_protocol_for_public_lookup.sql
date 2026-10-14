-- Exige CPF e protocolo para liberar dados pessoais na consulta pública.
-- A Edge Function continua sendo a única rota pública; ambas as RPCs ficam restritas a service_role.

create or replace function public.consultar_resultado_plantao(
  p_cpf text,
  p_protocolo text
)
returns table(
  nome text,
  profissao text,
  registro text,
  protocolo text,
  status text,
  hospitais text[],
  unidade_escalada text,
  plantao_escalado text,
  valor_pagamento numeric,
  data_resultado date
)
language sql
security definer
set search_path = ''
as $function$
  select
    i.nome,
    i.profissao,
    i.registro,
    i.protocolo,
    i.status,
    i.hospitais,
    i.unidade_escalada,
    i.plantao_escalado,
    i.valor_pagamento,
    c.data_resultado
  from public.inscricoes as i
  cross join public.plantao_configuracoes as c
  where i.cpf = regexp_replace(coalesce(p_cpf, ''), '\\D', '', 'g')
    and upper(btrim(i.protocolo)) = upper(btrim(coalesce(p_protocolo, '')))
    and length(btrim(coalesce(p_protocolo, ''))) between 6 and 64
  limit 1;
$function$;

revoke all on function public.consultar_resultado_plantao(text, text)
  from public, anon, authenticated;
grant execute on function public.consultar_resultado_plantao(text, text)
  to service_role;

-- Defesa em profundidade: a versão antiga também permanece inacessível ao navegador.
revoke all on function public.consultar_resultado_plantao(text)
  from public, anon, authenticated;

comment on function public.consultar_resultado_plantao(text, text) is
  'Consulta dados de acompanhamento somente com correspondência simultânea de CPF e protocolo; execução restrita a service_role.';
