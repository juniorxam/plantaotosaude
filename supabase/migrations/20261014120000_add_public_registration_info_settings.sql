-- Campos de publicação configuráveis pela gestão do Plantão TO Saúde.
-- A migração altera somente a tabela deste projeto; não toca em tabelas da Violetta.
alter table public.plantao_configuracoes
  add column if not exists responsavel_dados text,
  add column if not exists contato_privacidade text,
  add column if not exists base_legal_dados text,
  add column if not exists prazo_retencao_dados text;

-- A página pública só pode ler as colunas necessárias à inscrição e às informações
-- que a gestão decidiu publicar. updated_by continua privado.
revoke select on table public.plantao_configuracoes from public, anon, authenticated;
grant select (
  id,
  prazo_inscricao,
  data_resultado,
  valores_cargos,
  valores_cargos_24h,
  responsavel_dados,
  contato_privacidade,
  base_legal_dados,
  prazo_retencao_dados,
  updated_at
)
on table public.plantao_configuracoes to anon, authenticated;

comment on column public.plantao_configuracoes.responsavel_dados is 'Responsável/controlador pelo tratamento informado pela gestão; exibido publicamente somente quando preenchido.';
comment on column public.plantao_configuracoes.contato_privacidade is 'Canal público para solicitações de privacidade e LGPD; exibido somente quando preenchido.';
comment on column public.plantao_configuracoes.base_legal_dados is 'Base legal do tratamento validada pela coordenação; não preencher com texto genérico sem validação.';
comment on column public.plantao_configuracoes.prazo_retencao_dados is 'Prazo de retenção dos dados definido pela coordenação; exibido somente quando preenchido.';
