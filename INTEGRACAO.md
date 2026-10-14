# Integração — Plantão TO Saúde

## Arquitetura

O frontend estático está publicado na Vercel. O Supabase hospeda o PostgreSQL com RLS, autenticação, bucket privado de currículos e Edge Functions.

**Inscrição:** `index.html` → `POST /functions/v1/submit-plantao-inscricao` → validação e rate limit → Storage privado `curriculos` → RPC `register_plantao_inscricao` → `public.inscricoes` → protocolo.

**Acompanhamento:** `acompanhamento.html` → `POST /functions/v1/consultar-resultado-plantao` → limitador atômico → RPC `consultar_resultado_plantao` → status, hospital/plantão designados e pagamento quando definidos.

O navegador usa apenas a chave publicável. A chave `service_role` permanece no ambiente das Edge Functions e nunca deve ser publicada.

## Inscrição, agenda e idade

O formulário coleta nome, CPF, data de nascimento, telefone, e-mail, profissão, registro, vínculo/lotação, hospitais e plantões de interesse, observações, declaração e currículo. Currículo obrigatório: PDF, DOC ou DOCX até 5 MB; o arquivo é enviado à função, armazenado com nome aleatório no bucket privado e removido se a gravação falhar.

A escala possui dez opções: início às 07h e às 19h nos dias 31/10 e 01/11, e início às 07h em 02/11; cada início pode ter 12h ou 24h. Turnos de 24h terminam às 07h do dia seguinte. A inscrição aceita de uma a três preferências. A RPC reconhece também as antigas opções A/B/C e normaliza seus rótulos para os turnos equivalentes de 12h, preservando a disponibilidade escolhida.

O critério é ter 18 anos completos até 31/10/2026, data do primeiro plantão. A página limita a data de nascimento, a Edge Function valida novamente o valor e a RPC do banco rejeita cadastros fora do critério.

## Valores e designação final

`plantao_configuracoes.valores_cargos` guarda valores de 12h; `valores_cargos_24h` guarda valores separados de 24h. Não há cálculo automático de 24h como dobro do valor de 12h. Administradores devem configurar o valor apropriado para cada cargo/duração antes de finalizar como “escalado”.

No painel, a gestão registra o resultado (`pendente`, `confirmado`, `escalado` ou `recusado`) e escolhe hospital/plantão entre as preferências indicadas. A RPC `set_plantao_assignment` verifica administrador ativo, preferências, configuração do valor e combina status, hospital, plantão e pagamento em uma atualização auditada. “Confirmado” pode representar aceite anterior à designação; “escalado” requer hospital, plantão e valor configurado. O valor fica congelado no cadastro quando a atribuição é gravada.

## Consulta por CPF e privacidade

A consulta pública retorna nome, profissão, registro profissional, protocolo, status, hospitais de interesse, hospital e plantão designados, valor previsto quando configurado e data do resultado. Não retorna CPF, telefone, e-mail nem currículo.

A Edge Function valida o dígito verificador do CPF e aplica limite atômico de 10 consultas por IP em cada janela de 15 minutos. A chave de rate limit é HMAC do identificador de origem; IP em claro não é armazenado. A RPC `consultar_resultado_plantao` é executável somente por `service_role`, não por `anon` ou `authenticated`. O navegador nunca lê `public.inscricoes` diretamente.

## Painel administrativo

O painel (`/admin.html`) usa Supabase Auth e exige que o e-mail esteja ativo em `admin_users`. Oferece busca/filtros, indicadores, detalhe/impressão, exportação CSV, acesso temporário ao currículo, configuração de prazo/data de resultado, valores de 12h e 24h, atribuição de hospital/turno e histórico de auditoria.

A RPC de configuração de escala confere autorização no servidor. As inscrições e configurações atualizadas são auditadas; a tabela de auditoria é consultável apenas por administradores ativos.

## Deploy e validação

- Vercel: preset **Other**, `npm run build`, diretório `dist`.
- Supabase: manter ativas as Edge Functions `submit-plantao-inscricao` e `consultar-resultado-plantao`; nenhuma `service_role` no frontend.
- Aplicar as migrations do repositório no projeto Supabase correto antes de publicar uma versão que dependa das novas colunas/RPCs.
- Depois de publicar, validar HTTP 200 nas páginas, build e parsing dos scripts; testes com inscrição válida só devem usar cadastro controlado e coordenação para descarte.

Não presumir que o banco de produção esteja vazio. Esta documentação não inclui nem deve incluir CPF, currículo ou outros dados pessoais de candidatos.

## Privacidade e LGPD

Antes da divulgação pública, a organização precisa definir e publicar o responsável pelo tratamento, a finalidade e base legal, retenção, canal para solicitações dos titulares, regras de acesso interno e procedimento de descarte de currículos. O aviso curto do formulário não substitui uma política de privacidade completa.

## Arquivos de referência

- Migration de segurança da consulta: `20261013193000_protect_public_plantao_lookups.sql`.
- Migration de escala, idade e remuneração: `20261013195446_schedule_age_and_assignment.sql`.
- Página pública de inscrição: `index.html`.
- Consulta pública: `acompanhamento.html`.
- Painel: `admin.html`.


## Portal individual de documentos dos selecionados

- Gestão de documentos: `/selecionados.html`.
- Portal individual: `/documentos-candidato.html?token=...` (o token é aleatório, armazenado somente como hash, expira em até 14 dias e pode ser revogado pela Gestão).
- A Edge Function `candidate-documents-portal` valida o token em cada operação; o upload binário é feito pelo servidor depois de revalidar expiração/revogação. Não criar políticas públicas para `candidate_documents`, `candidate_portal_access`, `candidate_bank_details` ou `candidate_portal_audit`.
- O bucket `candidate-documents` deve continuar privado, limitado a PDF/JPEG/PNG e 10 MB por arquivo.
- A Gestão consegue gerar link, enviar e-mail, abrir WhatsApp com mensagem pronta, revogar o link, revisar documentos/dados bancários e consultar o histórico.
- Para habilitar envio automático pelo Resend, configurar nos secrets da Edge Function `candidate-documents-portal` as variáveis `RESEND_API_KEY` e `RESEND_FROM`. `RESEND_FROM` deve ser um remetente de domínio verificado e apropriado ao Plantão TO Saúde. Não usar credenciais no HTML, no GitHub ou no navegador.
- A variável opcional `CANDIDATE_PORTAL_BASE_URL` define a origem do portal; por padrão usa `https://plantaotosaude.vercel.app`.
- O WhatsApp é iniciado por link `wa.me` com texto pré-preenchido; o envio é confirmado manualmente pelo servidor responsável, não é disparo automático pela API.
- O histórico registra criação/revogação de links, acessos, envio/substituição de documentos, conferência de documentos e dados bancários e falhas de envio de e-mail.
