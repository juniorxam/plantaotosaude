# Plantão TO Saúde — plano e arquitetura

## Objetivo e direção visual

- Mobilização temporária de profissionais de saúde para hospitais estaduais do Tocantins durante o concurso de 01/11/2026.
- Identidade institucional contemporânea: azul profundo, verde-azulado, amarelo de atenção; composição responsiva, clara e acessível.
- A voz é institucional, direta e acolhedora; o formulário explica cada etapa, comunica erros junto aos campos e confirma o protocolo.

## Arquitetura atual

- `index.html`: página pública, formulário multi-etapas, validação no navegador e exibição de datas, prazo e valores.
- `acompanhamento.html`: consulta pública por CPF via Edge Function; não expõe CPF, telefone, e-mail nem currículo.
- `admin.html`: painel com Supabase Auth/RLS, definição do resultado e escala final, valores por cargo e duração, exportação e auditoria.
- `supabase/functions/submit-plantao-inscricao`: valida o cadastro, idade, turnos e arquivo antes de gravar usando uma RPC de servidor.
- `supabase/functions/consultar-resultado-plantao`: aplica limite por IP e consulta a RPC restrita a `service_role`.
- `supabase/migrations/`: schema, RLS, RPCs, auditoria e controles de consulta.
- Vercel hospeda as páginas estáticas; Supabase hospeda banco, Storage privado e Edge Functions.

## Requisitos da escala

- 31/10/2026: início às 07h e 19h, cada início disponível em duração de 12h ou 24h.
- 01/11/2026: início às 07h e 19h, cada início disponível em duração de 12h ou 24h.
- 02/11/2026: início às 07h, em 12h ou 24h.
- A inscrição preserva o limite de até três preferências de plantão e a gestão pode designar apenas hospital/plantão que o candidato indicou.
- Elegibilidade: 18 anos completos até 31/10/2026, primeiro dia da escala. A data é validada no navegador, Edge Function e RPC de gravação.
- Valores de 12h e 24h são configuráveis separadamente por cargo; o valor da escala final é congelado no registro. A duração de 24h não é presumida como duas vezes 12h; a gestão precisa definir a taxa apropriada.
- O resultado consultado por CPF mostra o status, hospital/plantão designados e pagamento quando definidos, mantendo os dados informativos já exibidos e sem expor contato ou currículo.

## Segurança e governança

- Nenhum INSERT público direto em `inscricoes`; o registro acontece via Edge Function e RPC `service_role`.
- A consulta por CPF passa pela Edge Function, tem limite atômico de 10 tentativas por IP a cada 15 minutos e HMAC para o identificador; a RPC não pode ser executada por `anon`/`authenticated`.
- Storage de currículos privado e links administrativos temporários.
- Alterações administrativas auditadas e protegidas por lista de administradores ativos.
- Antes do uso com dados reais, ainda é necessário publicar política de privacidade, definir retenção e canal para titulares, e executar um teste ponta a ponta controlado.

## Validação e publicação

1. Rodar o build estático e parse dos scripts/Edge Functions.
2. Aplicar migration aditiva no Supabase e publicar Edge Functions atualizadas.
3. Publicar a UI pela branch principal (deploy Vercel integrado ao GitHub).
4. Fazer smoke test das páginas públicas, sem consultar ou inserir dados pessoais reais.
