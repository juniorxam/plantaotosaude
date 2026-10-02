# Plantão TO Saúde

Landing page institucional para inscrição de profissionais de saúde que não participarão da prova da SES-TO em 01/11/2026 e desejam atuar como reforço temporário nos hospitais estaduais do Tocantins.

## Stack

- HTML5, CSS3 e JavaScript puro;
- formulário responsivo com validação client-side;
- Supabase + Edge Function para receber inscrições públicas com validação no servidor;
- Supabase Storage privado para currículos;
- RLS e Supabase Auth para proteger o painel administrativo;
- build estático compatível com Vercel.

## Desenvolvimento local

```bash
python3 -m http.server 3000
```

Abra `http://localhost:3000`.

## Supabase

A tabela `public.inscricoes` é criada pelas migrações do diretório `supabase/migrations`. O envio público passa pela Edge Function `submit-plantao-inscricao`, que recebe o formulário e o currículo, aplica validações e rate limiting, grava o currículo no bucket privado e chama a RPC `register_plantao_inscricao` com privilégios de servidor. A RPC valida novamente os dados, grava a inscrição como `pendente` e retorna somente o protocolo. O navegador não executa a RPC diretamente e não possui acesso público ao Storage ou à tabela de inscrições.

Detalhes adicionais estão em [INTEGRACAO.md](INTEGRACAO.md).

## Administração

O painel administrativo está em `/admin.html`. O acesso usa Supabase Auth e a tabela `admin_users` como segunda camada de autorização. O painel permite consultar inscrições, filtrar por status, atualizar o status e exportar os resultados para CSV. Nenhuma senha ou `service_role` é armazenada no código.

## Deploy no Vercel

O projeto é estático. No Vercel, use:

- **Framework Preset:** Other;
- **Build Command:** `npm run build`;
- **Output Directory:** `dist`;
- O build copia `index.html` e `admin.html` para o diretório final;
- **Install Command:** deixe vazio.

O repositório está preparado para implantação automática a cada push na branch `main`.

### Fluxo público de inscrição

`index.html` → `submit-plantao-inscricao` → Storage privado (`curriculos`) → `register_plantao_inscricao` → `inscricoes`.

A `service_role` existe somente no ambiente da Edge Function e nunca deve ser colocada no HTML. O cadastro público não possui privilégio de `INSERT` direto na tabela.


### Currículo anexado

O formulário público aceita currículo em **PDF, DOC ou DOCX até 5 MB**. Os arquivos ficam em bucket privado do Supabase Storage e o painel administrativo gera links temporários somente para usuários administrativos autorizados.
