# Integração do formulário — Plantão TO Saúde

## Supabase configurado

O formulário já está conectado ao projeto Supabase configurado para o site. As inscrições são enviadas para `public.inscricoes` pela API REST. A tabela possui RLS habilitado e a chave usada no frontend é uma chave publicável; a política permite somente inserções com declaração marcada, pelo menos um hospital e pelo menos um plantão. Não há política de leitura pública.

Para consultar as inscrições, use o painel autenticado do Supabase ou um backend/admin com credenciais próprias. Nunca coloque uma `service_role key` no HTML.

O `index.html` valida os dados no navegador (incluindo CPF, telefone e data de nascimento) e chama a função RPC `register_plantao_inscricao`. A função grava a inscrição com status `pendente` e retorna somente o protocolo gerado; o navegador não recebe a linha completa da tabela. A função RPC usa `SECURITY DEFINER` com `search_path` vazio, valida novamente os campos e valores permitidos no banco e tem execução liberada somente para `anon`. O acesso direto de leitura à tabela continua bloqueado. O bloco de integração fica no final do `<script>`.

> Antes de publicar, defina também política de privacidade, responsável pelo tratamento dos dados e prazo de retenção. O formulário coleta dados pessoais e profissionais, incluindo CPF.

## 1. Google Forms + Planilha

1. Crie um Google Formulários com uma pergunta para cada campo do site.
2. No formulário, use caixas de seleção para hospitais e plantões.
3. Abra **Respostas → Vincular ao Planilhas Google**.
4. Obtenha a URL de envio pelo HTML do formulário ou use Apps Script como endpoint intermediário.
5. No JavaScript, troque o `console.log` por um `fetch` para o endpoint do Google Apps Script:

```js
await fetch('URL_DO_SEU_APPS_SCRIPT', {
  method: 'POST',
  mode: 'no-cors',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data)
});
```

Um Apps Script mínimo pode receber `e.postData.contents`, converter o JSON e usar `SpreadsheetApp.openById(...).appendRow(...)`. Proteja o endpoint com uma chave ou token próprio e não exponha credenciais sensíveis no HTML.

## 2. Formspree

1. Crie um formulário em [Formspree](https://formspree.io/).
2. Copie o endpoint fornecido, normalmente no formato `https://formspree.io/f/SEU_ID`.
3. Altere o `<form>` para incluir `action` e `method`:

```html
<form id="registration-form" action="https://formspree.io/f/SEU_ID" method="POST" novalidate>
```

4. No handler JavaScript, depois da validação, use:

```js
const response = await fetch(form.action, {
  method: 'POST',
  body: new FormData(form),
  headers: { Accept: 'application/json' }
});
if (!response.ok) throw new Error('Não foi possível enviar a inscrição.');
```

Mantenha a mensagem de sucesso somente depois de confirmar `response.ok` e trate erros de rede com uma mensagem ao usuário.

## 3. Backend próprio (Node.js ou Python)

Crie uma rota `POST /api/inscricoes`, valide novamente todos os dados no servidor e armazene apenas o necessário. A validação do navegador nunca deve ser a única barreira.

Exemplo de envio no frontend:

```js
const response = await fetch('/api/inscricoes', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data)
});
const result = await response.json();
if (!response.ok) throw new Error(result.message || 'Erro ao enviar inscrição.');
```

No backend, recomenda-se:

- validar CPF, e-mail, telefone, profissão, hospitais e plantões permitidos;
- registrar data/hora e um identificador da inscrição;
- aplicar rate limiting, proteção contra spam e logs sem CPF completo;
- usar HTTPS, controle de acesso e criptografia/segurança do banco;
- retornar mensagens genéricas de erro ao navegador;
- documentar base legal, prazo de retenção e canal de atendimento à LGPD.

O projeto está em HTML estático de propósito: a camada de recebimento pode ser adicionada depois sem reescrever a interface.


## Currículo profissional

O formulário público exige currículo em PDF, DOC ou DOCX de até 5 MB. O arquivo é armazenado no bucket privado `curriculos` do Supabase Storage, com nome aleatório e sem CPF/nome no caminho.

A inscrição grava apenas o caminho do objeto em `inscricoes.curriculo_path`. O painel administrativo, após autenticação, pode gerar um link temporário para baixar o currículo. O arquivo não é exposto por URL pública permanente.
