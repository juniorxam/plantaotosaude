# Plantão TO Saúde — status

## Entregas implementadas e verificadas

- [x] Administradores ativos podem liberar/desativar outros e-mails, preservando o login pelo Supabase Auth.
- [x] Auditoria de alterações em inscrições, configurações, designações de escala e permissões administrativas.
- [x] Página pública de acompanhamento com CPF + protocolo; retorno mínimo sem CPF, telefone, e-mail ou currículo.
- [x] Proteção da consulta: validação do dígito verificador, limite atômico de 10 consultas por IP em 15 minutos, HMAC no identificador e RPC de leitura acessível somente a `service_role`.
- [x] Agenda com dez opções: 31/10 e 01/11/2026 às 07h e 19h, e 02/11 às 07h, cada início com duração de 12h ou 24h.
- [x] Seleção de até três preferências e designação final de um único plantão pelo painel administrativo.
- [x] Idade mínima de 18 anos completos até 31/10/2026, validada no formulário, Edge Function e RPC de cadastro no banco.
- [x] Consulta mostra status e, quando definidos, hospital, plantão final e valor congelado do pagamento.
- [x] Valores de 12h e 24h separados por cargo; sem presumir que 24h seja o dobro de 12h.
- [x] Migration aplicada no Supabase: `20261013195446_schedule_age_and_assignment`.
- [x] Colunas e permissões das RPCs confirmadas no banco; consulta direta não executável por `anon`/`authenticated`.
- [x] Edge Functions publicadas: `submit-plantao-inscricao` v13 e `consultar-resultado-plantao` v4, ambas com `verify_jwt=false` conforme as rotas públicas e autenticação/validação próprias.
- [x] Build, sintaxe JavaScript/TypeScript, consistência dos dez turnos e `git diff --check` validados localmente.
- [x] Teste não destrutivo da Edge Function com data inelegível: HTTP 400 e mensagem de idade; nenhum currículo foi enviado e nenhum cadastro foi criado.
- [x] README, guia de integração e plano do produto atualizados.

## Pendências

- [x] Commit enviado ao branch `main`; deployment de produção Vercel em `READY` e páginas inicial, admin e acompanhamento responderam HTTP 200 com os novos campos/controles.
- [ ] Informar/configurar no painel os valores de 24h por cargo antes de finalizar inscrições de 24h como escaladas. O sistema não cria nem infere taxas ausentes.
- [x] Criar e vincular página de política de privacidade com categorias de dados, finalidades, compartilhamento, segurança, retenção, direitos e descarte.
- [ ] Completar a política antes de considerá-la definitiva: identificar formalmente o controlador/responsável, divulgar canal direto para solicitações LGPD, documentar a base legal e definir prazo operacional de retenção.
- [ ] Realizar teste ponta a ponta com inscrição de teste controlada e plano de descarte; nenhum cadastro de teste válido foi criado nesta atualização.
