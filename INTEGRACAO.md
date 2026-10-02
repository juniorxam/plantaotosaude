# Integração — Plantão TO Saúde

## Arquitetura atual

O formulário público está integrado diretamente ao Supabase por meio da Edge Function `submit-plantao-inscricao`.

Fluxo:

`index.html`
→ `POST /functions/v1/submit-plantao-inscricao`
→ validação e rate limiting
→ Storage privado `curriculos`
→ RPC `register_plantao_inscricao`
→ tabela `public.inscricoes`
→ retorno do protocolo.

O navegador usa somente a chave publicável do Supabase. A `service_role` existe exclusivamente no ambiente da Edge Function.

## Formulário público

O `index.html` envia `multipart/form-data` com:

- nome;
- CPF;
- data de nascimento;
- telefone;
- e-mail;
- profissão;
- registro profissional;
- hospitais escolhidos;
- plantões escolhidos;
- observações;
- declaração;
- currículo;
- campos técnicos anti-bot.

A validação ocorre em duas camadas:

1. navegador, para orientar o preenchimento;
2. Edge Function/RPC, como validação de segurança.

O currículo é obrigatório e aceita:

- PDF;
- DOC;
- DOCX;
- até 5 MB.

O nome do arquivo armazenado é aleatório e não contém CPF ou nome do profissional.

## Proteções

A Edge Function aplica:

- validação de método HTTP;
- validação de campos;
- validação de CPF;
- lista fechada de profissões;
- lista fechada de hospitais;
- lista fechada de plantões;
- prevenção de seleções duplicadas;
- honeypot;
- tempo mínimo de preenchimento;
- rate limiting por identificador de origem;
- tratamento específico de CPF duplicado;
- limpeza do currículo quando a inscrição falha após o upload.

A tabela `public.inscricoes` possui RLS e não permite INSERT público.

A RPC `register_plantao_inscricao` é `SECURITY DEFINER`, usa `search_path` controlado, valida os dados novamente e possui execução liberada somente para `service_role`.

## Storage

O bucket `curriculos` é privado.

Não existe upload público direto pelo navegador. A Edge Function grava os arquivos usando credenciais de servidor.

O painel administrativo gera URLs assinadas temporárias para download, somente após a autenticação e autorização do administrador.

## Painel administrativo

O arquivo `admin.html` usa Supabase Auth.

Depois do login, a autorização é reforçada pela tabela `admin_users`.

O painel oferece:

- consulta das inscrições;
- busca textual;
- filtros por status, hospital e plantão;
- indicadores de quantidade;
- alteração de status;
- visualização dos detalhes;
- download temporário do currículo;
- impressão;
- exportação CSV;
- logout.

O acesso público não consegue consultar a tabela de inscrições nem a tabela de administradores.

## Estado atual verificado

A infraestrutura foi revisada sem inserir registros de teste.

Estado atual:

- inscrições: **0**;
- currículos: **0**;
- RLS em `inscricoes`: ativo;
- RLS em `admin_users`: ativo;
- INSERT público em `inscricoes`: bloqueado;
- SELECT público em `inscricoes`: bloqueado;
- SELECT público em `admin_users`: bloqueado;
- execução pública da RPC: bloqueada;
- execução da RPC por `service_role`: permitida.

## Deploy

### Vercel

O frontend é estático.

Configuração:

- Framework Preset: **Other**;
- Build Command: `npm run build`;
- Output Directory: `dist`;
- Install Command: vazio.

A Edge Function não é publicada pelo Vercel. Ela permanece no Supabase.

### Supabase

A função implantada é:

`submit-plantao-inscricao`

Ela deve permanecer ativa com os segredos necessários configurados no ambiente do Supabase. Nunca copie a `service_role` para o frontend.

## Privacidade e LGPD

O formulário coleta dados pessoais e profissionais, incluindo CPF e currículo.

Antes da divulgação pública, é necessário definir e publicar:

- responsável pelo tratamento;
- finalidade do tratamento;
- base legal aplicável;
- prazo de retenção;
- canal para solicitações dos titulares;
- regras de acesso interno aos dados;
- procedimento para descarte dos currículos.

O texto exibido no formulário informa que os dados serão usados para análise, contato e organização da mobilização, mas isso não substitui uma política de privacidade completa.

## Teste de produção

A revisão atual foi não destrutiva.

Não foi feito um POST público de inscrição porque isso criaria um registro e um currículo no banco. Como o ambiente foi solicitado sem cadastros, o teste end-to-end de uma inscrição real deve ser feito posteriormente com um registro de teste controlado e depois removido, se necessário.

## Separação de projetos

Este documento trata exclusivamente do **Plantão TO Saúde**.

**Karine Joias é outro projeto e não faz parte desta integração.**
