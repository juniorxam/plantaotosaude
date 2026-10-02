# Plantão TO Saúde

Landing page institucional para inscrição de profissionais de saúde que não participarão da prova da SES-TO em 01/11/2026 e desejam atuar como reforço temporário nos hospitais estaduais do Tocantins.

## Stack

- HTML5, CSS3 e JavaScript puro;
- formulário responsivo com validação client-side;
- Supabase Edge Function para recebimento público das inscrições;
- Supabase Storage privado para currículos;
- PostgreSQL/RLS e Supabase Auth para o painel administrativo;
- deploy estático compatível com Vercel.

## Estrutura

- `index.html` — página pública e formulário;
- `admin.html` — painel administrativo;
- `logo.svg` — identidade visual do projeto;
- `supabase/functions/submit-plantao-inscricao/index.ts` — endpoint público seguro;
- `supabase/migrations/` — histórico das alterações do banco;
- `INTEGRACAO.md` — arquitetura e checklist operacional;
- `package.json` / `vercel.json` — build estático.

## Desenvolvimento local

~~~bash
python3 -m http.server 3000
~~~

Abra `http://localhost:3000`.

Para validar o pacote estático no mesmo formato usado pelo Vercel:

~~~bash
npm run build
~~~

O comando gera `dist/` com os arquivos públicos necessários. A Edge Function do Supabase é implantada separadamente e não faz parte do build do Vercel.

## Arquitetura de inscrição

O fluxo público é:

`index.html` → `submit-plantao-inscricao` → bucket privado `curriculos` → RPC `register_plantao_inscricao` → `public.inscricoes`

A inscrição pública **não** faz INSERT direto na tabela e **não** acessa o Storage diretamente.

A Edge Function:

1. recebe `multipart/form-data`;
2. valida CPF, e-mail, telefone, profissão, hospitais, plantões e declaração;
3. exige currículo PDF/DOC/DOCX de até 5 MB;
4. aplica proteção anti-bot e rate limiting;
5. grava o currículo com nome aleatório no bucket privado;
6. chama a RPC com privilégios de servidor;
7. remove o currículo se a gravação da inscrição falhar;
8. retorna somente o protocolo da inscrição.

A RPC fica disponível para execução apenas pelo `service_role`, usado internamente pela Edge Function.

## Supabase

O projeto utiliza:

- tabela `public.inscricoes`;
- tabela `public.admin_users`;
- tabela técnica `public.submission_rate_limits`;
- bucket privado `curriculos`;
- Supabase Auth para administradores;
- Edge Function `submit-plantao-inscricao`;
- RPC `register_plantao_inscricao`.

A chave publicável pode permanecer no frontend. **Nunca coloque uma chave `service_role` no HTML, no repositório ou em arquivos públicos.**

O banco atualmente permanece sem dados de teste: nenhuma inscrição e nenhum currículo foram inseridos.

## Administração

O painel está em `/admin.html`.

O acesso exige autenticação no Supabase Auth e autorização adicional pela tabela `admin_users`. Usuários administrativos autorizados podem:

- consultar inscrições;
- pesquisar por diversos campos;
- filtrar por status, hospital e plantão;
- visualizar detalhes;
- atualizar status;
- gerar link temporário para currículo;
- imprimir uma inscrição;
- exportar CSV.

O bucket de currículos permanece privado e os links de download são temporários.

## Deploy no Vercel

Configuração atual:

- **Framework Preset:** Other;
- **Build Command:** `npm run build`;
- **Output Directory:** `dist`;
- **Install Command:** vazio.

O Vercel hospeda apenas a camada estática. O backend de inscrição permanece no Supabase.

Antes de publicar, confirme:

- domínio e HTTPS configurados;
- Edge Function implantada e ativa;
- variáveis/segredos da Edge Function configurados no Supabase;
- usuário administrativo criado no Supabase Auth e autorizado em `admin_users`;
- política de privacidade e responsável pelo tratamento dos dados definidos;
- prazo de retenção e canal de atendimento aos titulares definidos.

## Separação de projetos

Este repositório é exclusivamente do **Plantão TO Saúde**.

O projeto **Karine Joias** é independente e não faz parte desta aplicação. Não há código de Karine Joias neste repositório.

## Limite do teste atual

A infraestrutura, permissões, RLS, Storage e Edge Function foram revisados sem inserir dados reais ou fictícios. Um teste público completo de POST não foi executado porque ele criaria uma inscrição; o banco foi mantido deliberadamente com zero registros.
