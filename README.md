# Plantão TO Saúde

Landing page institucional para inscrição de profissionais de saúde que não participarão da prova da SES-TO em 01/11/2026 e desejam atuar como reforço temporário nos hospitais estaduais do Tocantins.

## Stack

- HTML5, CSS3 e JavaScript puro;
- formulário responsivo com validação client-side;
- Supabase REST API com RLS para armazenar inscrições;
- build estático compatível com Vercel.

## Desenvolvimento local

```bash
python3 -m http.server 3000
```

Abra `http://localhost:3000`.

## Supabase

A tabela `public.inscricoes` é criada pela migração `create_inscricoes_plantao_to_saude`. Ela permite apenas `INSERT` público com declaração, hospitais e plantões válidos. A leitura deve ser feita apenas por usuários/serviços administrativos autenticados.

Detalhes adicionais estão em [INTEGRACAO.md](INTEGRACAO.md).

## Deploy no Vercel

O projeto é estático. No Vercel, use:

- **Framework Preset:** Other;
- **Build Command:** `npm run build`;
- **Output Directory:** `dist`;
- **Install Command:** deixe vazio.

O repositório está preparado para implantação automática a cada push na branch `main`.
