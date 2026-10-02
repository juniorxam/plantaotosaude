-- Harden public Plantão TO Saúde submissions.
-- Public users may only insert the form fields; generated metadata stays server-side.

revoke insert on table public.inscricoes from anon, authenticated;

grant insert (
  nome,
  cpf,
  nascimento,
  telefone,
  email,
  profissao,
  registro,
  hospitais,
  plantoes,
  observacoes,
  declaracao
) on table public.inscricoes to anon;

drop policy if exists "Permitir envio de inscricoes" on public.inscricoes;

create policy "Permitir envio de inscricoes"
on public.inscricoes
for insert
to anon
with check (
  declaracao = true
  and status = 'pendente'
  and cardinality(hospitais) between 1 and 6
  and hospitais <@ array[
    'Palmas — Hospital Geral de Palmas',
    'Araguaína — Hospital Regional de Araguaína',
    'Gurupi — Hospital Regional de Gurupi',
    'Paraíso do Tocantins — Hospital Regional de Paraíso',
    'Porto Nacional — Hospital Regional de Porto Nacional',
    'Augustinópolis — Hospital Regional de Augustinópolis'
  ]::text[]
  and cardinality(plantoes) between 1 and 3
  and plantoes <@ array[
    'A — Véspera, noturno — 31/10/2026, 19h às 7h de 01/11',
    'B — Dia do concurso, diurno — 01/11/2026, 7h às 19h',
    'C — Dia do concurso, noturno — 01/11/2026, 19h às 7h de 02/11'
  ]::text[]
  and length(trim(nome)) between 5 and 150
  and length(regexp_replace(cpf, '\\D', '', 'g')) = 11
  and length(trim(telefone)) between 10 and 20
  and length(trim(email)) between 5 and 254
  and length(trim(profissao)) between 2 and 100
  and length(trim(registro)) between 2 and 100
);
