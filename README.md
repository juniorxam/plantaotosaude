# Plantão TO Saúde

Aplicação de mobilização temporária de profissionais de saúde para hospitais estaduais do Tocantins durante o concurso da SES-TO em 01/11/2026.

## Aplicação e arquitetura

O frontend é HTML/CSS/JavaScript estático. A Vercel hospeda as páginas; Supabase fornece PostgreSQL/RLS, autenticação, Storage privado e Edge Functions.

- `index.html` — agenda, inscrição multi-etapas e consulta rápida;
- `acompanhamento.html` — acompanhamento por CPF;
- `admin.html` — painel autenticado para revisar cadastros, definir resultado e escala, configurar remuneração e auditar alterações;
- `supabase/functions/submit-plantao-inscricao/index.ts` — validação e gravação segura de inscrições;
- `supabase/functions/consultar-resultado-plantao/index.ts` — consulta protegida por CPF;
- `supabase/migrations/` — schema, RPCs, políticas, auditoria e controles de segurança;
- `INTEGRACAO.md` — arquitetura e checklist operacional.

A chave publicável do Supabase pode estar no frontend. **Nunca inclua `service_role` no HTML, no repositório ou em arquivos públicos.**

## Agenda e elegibilidade

Há dez opções: em 31/10 e 01/11/2026, início às 07h ou 19h, cada um em 12h ou 24h; em 02/11/2026, início às 07h, em 12h ou 24h. As opções de 24h terminam às 07h do dia seguinte ao início. O formulário aceita até três preferências de plantão.

A pessoa deve ter 18 anos completos até **31/10/2026**, data do primeiro plantão. O navegador, a Edge Function e a RPC do banco verificam essa regra; a validação do frontend não é a única barreira.

## Inscrição e acompanhamento

Fluxo de cadastro: `index.html` → Edge Function `submit-plantao-inscricao` → Storage privado `curriculos` → RPC `register_plantao_inscricao` → tabela `public.inscricoes`. A inscrição pública não faz INSERT direto na tabela nem upload direto no Storage. A RPC de cadastro só pode ser chamada por `service_role`.

A página de acompanhamento usa `consultar-resultado-plantao`, que valida o CPF e limita a consulta a 10 tentativas por IP em cada janela de 15 minutos. O identificador de IP é armazenado como HMAC; a RPC que lê o cadastro não pode ser executada por `anon` ou `authenticated`.

A consulta retorna nome, profissão, registro profissional, protocolo, status, hospitais de interesse, hospital e plantão designados, valor previsto quando configurado e data do resultado. Não retorna CPF, telefone, e-mail nem currículo.

## Painel e valores

O painel exige login no Supabase Auth e autorização na tabela `admin_users`. Administradores ativos podem revisar inscrições, baixar currículo por link temporário, exportar CSV, imprimir detalhes, configurar o prazo/data de resultado e registrar status, hospital e plantão final.

A atribuição de escala ocorre por uma RPC que confirma a autorização administrativa e os dados da inscrição. A gestão escolhe o hospital e o plantão a partir das preferências informadas pelo profissional. Para marcar como “escalado”, o valor precisa estar configurado para o cargo e a duração.

Os valores de 12h e 24h são mantidos separadamente em `plantao_configuracoes` e podem ser editados no painel. **O sistema não presume que 24h custe o dobro de 12h.** O valor final é guardado no cadastro quando a escala é registrada, permitindo que o acompanhamento mostre o mesmo valor posteriormente.

## Desenvolvimento e publicação

Execute `npm run build` para gerar `dist/`. A Edge Function Supabase é publicada separadamente da Vercel. Configuração estática do Vercel: preset **Other**, comando `npm run build`, saída `dist`.

A migration `20261013195446_schedule_age_and_assignment.sql` adiciona a escala final, os valores por turno de 24h, a validação de idade, a expansão das opções de plantão e a RPC administrativa de atribuição. Preferências antigas A/B/C são convertidas para os turnos equivalentes de 12h.

## Antes de divulgar para inscrições reais

Ainda é necessário confirmar/publicar a política de privacidade, incluindo responsável pelo tratamento, finalidade/base legal, retenção, canal para titulares e descarte de currículos. Também é necessário configurar explicitamente os valores de 24h no painel antes de finalizar escalas de 24h e realizar um teste ponta a ponta controlado. Não presumir que o banco esteja vazio e não usar CPF real em testes.

Este repositório trata exclusivamente do Plantão TO Saúde; outros projetos do usuário não fazem parte desta aplicação.
