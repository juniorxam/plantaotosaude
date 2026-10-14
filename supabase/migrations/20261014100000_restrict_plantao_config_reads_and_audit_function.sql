-- Restrict public configuration reads to fields required by the storefront.
-- Keep RLS policies in place; this narrows column-level privileges as well.
revoke select on table public.plantao_configuracoes from public, anon, authenticated;

grant select (
  id,
  prazo_inscricao,
  data_resultado,
  valores_cargos,
  valores_cargos_24h,
  updated_at
)
on table public.plantao_configuracoes
to anon, authenticated;

-- This function is intended to run only from its database triggers.
-- Trigger execution does not require callers to have direct EXECUTE permission.
revoke all on function public.write_plantao_audit()
from public, anon, authenticated;

comment on function public.write_plantao_audit() is
  'Internal trigger function for Plantão TO Saúde audit logging; direct execution is revoked.';
