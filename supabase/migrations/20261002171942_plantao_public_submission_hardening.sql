-- Plantão TO Saúde: public submission hardening.
-- The public browser submits only through the submit-plantao-inscricao Edge Function.

drop policy if exists "Permitir envio de inscricoes" on public.inscricoes;

revoke all on table public.inscricoes from anon;
revoke all on table public.inscricoes from public;
grant select, update on table public.inscricoes to authenticated;

revoke all on table public.admin_users from anon;
revoke all on table public.admin_users from public;
revoke insert, update, delete, truncate, references, trigger on table public.admin_users from authenticated;
grant select on table public.admin_users to authenticated;

revoke all on table public.submission_rate_limits from anon;
revoke all on table public.submission_rate_limits from authenticated;
revoke all on table public.submission_rate_limits from public;

revoke execute on function public.register_plantao_inscricao(
  text,text,date,text,text,text,text,text[],text[],text,text
) from anon, authenticated, public;
grant execute on function public.register_plantao_inscricao(
  text,text,date,text,text,text,text,text[],text[],text,text
) to service_role;

drop policy if exists "Public can upload curricula" on storage.objects;
drop policy if exists "Public can read curricula" on storage.objects;
drop policy if exists "Public can delete curricula" on storage.objects;
drop policy if exists "Anon can upload curricula" on storage.objects;
drop policy if exists "Anon can read curricula" on storage.objects;
drop policy if exists "Anon can delete curricula" on storage.objects;
drop policy if exists "Authenticated can upload curricula" on storage.objects;
drop policy if exists "Authenticated can read curricula" on storage.objects;
drop policy if exists "Authenticated can delete curricula" on storage.objects;
drop policy if exists "Allow public curriculum uploads" on storage.objects;
drop policy if exists "Allow public curriculum reads" on storage.objects;
drop policy if exists "Allow public curriculum cleanup" on storage.objects;
