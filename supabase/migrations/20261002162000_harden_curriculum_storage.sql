-- Endurece o Storage de currículos:
-- o formulário público só precisa criar e, em caso de falha, remover o próprio arquivo.
-- leitura continua exclusiva dos administradores autenticados.
drop policy if exists "Public curriculum upload metadata" on storage.objects;

drop policy if exists "Public curriculum uploads" on storage.objects;
create policy "Public curriculum uploads"
on storage.objects for insert
to anon
with check (
  bucket_id = 'curriculos'
  and name ~ '^curriculos/[0-9a-fA-F-]{36}\.(pdf|doc|docx)$'
);

drop policy if exists "Public curriculum cleanup" on storage.objects;
create policy "Public curriculum cleanup"
on storage.objects for delete
to anon
using (
  bucket_id = 'curriculos'
  and name ~ '^curriculos/[0-9a-fA-F-]{36}\.(pdf|doc|docx)$'
);

drop policy if exists "Admins can read curricula" on storage.objects;
create policy "Admins can read curricula"
on storage.objects for select
to authenticated
using (
  bucket_id = 'curriculos'
  and exists (
    select 1
    from public.admin_users a
    where a.ativo = true
      and lower(a.email) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  )
);
