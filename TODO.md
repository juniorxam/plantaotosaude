# Plantão TO Saúde — status de conclusão

## Entregas implementadas e verificadas

- [x] Permissões administrativas delegáveis: administradores ativos podem liberar/desativar outros e-mails, preservando o login pelo Supabase Auth.
- [x] Auditoria de alterações em inscrições, configurações e permissões administrativas.
- [x] Página pública de acompanhamento por CPF, com os dados atuais do cadastro, status, resultado e unidade escalada.
- [x] Proteção da consulta: validação do dígito verificador, limite atômico de 10 consultas por IP em 15 minutos, HMAC no identificador e RPC de leitura acessível somente a `service_role`.
- [x] Migration de proteção aplicada no Supabase; Edge Function `consultar-resultado-plantao` ativa (versão 3).
- [x] Site publicado na Vercel; páginas inicial, administração e acompanhamento responderam HTTP 200.
- [x] Build estático validado com `npm run build`; teste negativo confirmou resposta 400 para CPF inválido e HTTP 401 para chamada direta da RPC com chave pública.

## Pendências operacionais antes de tratar inscrições reais

- [ ] Definir e publicar a política de privacidade, incluindo controlador, finalidade/base legal, retenção, canal para solicitações dos titulares e procedimento de descarte dos currículos.
- [ ] Fazer um teste ponta a ponta controlado de inscrição usando cadastro de teste autorizado e removê-lo ao final; não foi feito POST válido para evitar inserir dados de teste sem coordenação.
