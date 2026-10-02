-- Public registrations are handled exclusively by the submit-plantao-inscricao Edge Function.
-- Keep the inscricoes table free of legacy anonymous INSERT policies.

DROP POLICY IF EXISTS "Permitir envio de inscricoes" ON public.inscricoes;
