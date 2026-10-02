# Plantão TO Saúde

Landing page institucional para inscrição de profissionais de saúde que não participarão da prova da SES-TO em 01/11/2026 e desejam atuar como reforço temporário nos hospitais estaduais do Tocantins.

## Stack

- HTML5, CSS3 e JavaScript puro;
- formulário responsivo com validação client-side;
- Supabase REST API com RLS para armazenar inscrições;
- build estático compatível com Vercel.

## Desenvolvimento local

```bash
python3 -m http.server 3000
```

Abra `http://localhost:3000`.

## Supabase

A tabela `public.inscricoes` é criada pelas migrações do diretório `supabase/migrations`. O envio público aceita somente as colunas do formulário e exige declaração, CPF/telefone/e-mail válidos em formato básico e hospitais/plantões pertencentes às opções oficiais. A leitura deve ser feita apenas por usuários administrativos autenticados.

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
