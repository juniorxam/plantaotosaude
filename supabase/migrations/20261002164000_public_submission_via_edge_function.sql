-- O cadastro público agora passa pela Edge Function, que usa a chave de serviço
-- somente no servidor. O navegador não precisa mais acessar Storage nem RPC diretamente.
drop policy if exists "Public curriculum uploads" on storage.objects;
drop policy if exists "Public curriculum cleanup" on storage.objects;
drop policy if exists "Public curriculum upload metadata" on storage.objects;

revoke execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text[],text[],text,text) from anon, authenticated, public;
grant execute on function public.register_plantao_inscricao(text,text,date,text,text,text,text[],text[],text,text) to service_role;
