# Plantão TO Saúde — plano implementado

## Direção visual

- **Movimento:** institucional contemporâneo de saúde, com precisão editorial e acolhimento cívico.
- **Princípios:** clareza primeiro; confiança sem burocracia; contraste acessível; ação orientada por etapas.
- **Filosofia de cor:** azul profundo comunica segurança pública; azul médio orienta e informa; verde-azulado sinaliza cuidado e disponibilidade; amarelo marca decisões e atenção sem transformar a página em alerta excessivo.
- **Paradigma de layout:** composição editorial em blocos assimétricos: hero com painel de data, conteúdo em duas colunas para contexto, cards em ritmo modular e formulário dividido entre orientação e ação.
- **Elementos assinatura:** marca em forma de cruz arredondada, linhas/contornos circulares discretos e bordas superiores codificadas por cor nos cards.
- **Interação:** o usuário recebe contexto antes da decisão; seleções de hospitais e plantões respondem visualmente; erros aparecem junto ao campo relacionado; sucesso confirma a ação sem sair da página.
- **Animação:** transições curtas de elevação, cor e sombra; sem movimento contínuo que distraia a leitura ou prejudique acessibilidade.
- **Tipografia:** Segoe UI/Arial, com títulos compactos e fortes, corpo de texto aberto e microcopy em pesos médios/altos.
- **Essência:** a mobilização temporária que conecta profissionais disponíveis aos hospitais que precisam manter o cuidado; confiável, direto, solidário.
- **Voz:** institucional, clara e humana. Exemplos: “Reforço que cuida quando o Estado mais precisa.” e “Escolha onde sua presença pode fazer diferença.”
- **Marca:** wordmark acompanhado de uma cruz arredondada assimétrica, remetendo à saúde e à cooperação entre rede e profissionais.
- **Cor proprietária:** verde-azulado `#00897b`, usado como sinal de disponibilidade e ação.

## Estrutura

- `index.html`: página única autocontida, com conteúdo, CSS responsivo, navegação, formulário, validação client-side e comentários de integração.
- `manus-routes.json`: manifesto estático da rota `/` para o Webdev.
- `INTEGRACAO.md`: instruções para Google Forms/Planilha, Formspree e backend próprio.

A aplicação é estática, portanto não requer servidor ou banco nesta primeira versão. O formulário fica em modo demonstração até que um endpoint de recebimento seja configurado.
