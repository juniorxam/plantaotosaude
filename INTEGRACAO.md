# Integração do formulário — Plantão TO Saúde

O `index.html` entregue funciona em modo demonstração: valida os campos no navegador, exibe uma mensagem de sucesso, limpa o formulário e registra o objeto enviado no console com `console.log`. Para receber inscrições de verdade, substitua o bloco indicado no final do `<script>` por uma das opções abaixo.

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
