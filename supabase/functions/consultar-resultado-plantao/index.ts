import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, authorization, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
const digits = (value: FormDataEntryValue | string | null) => String(value ?? "").replace(/\D/g, "");

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ message: "Método não permitido." }, 405);
  try {
    const body = request.headers.get("content-type")?.includes("application/json") ? await request.json() : await request.formData();
    const cpf = digits(body instanceof FormData ? body.get("cpf") : body?.cpf);
    if (cpf.length !== 11) return json({ message: "Informe um CPF válido." }, 400);
    const { data, error } = await supabase.rpc("consultar_resultado_plantao", { p_cpf: cpf });
    if (error) throw error;
    const result = Array.isArray(data) ? data[0] : data;
    if (!result) return json({ encontrada: false });
    return json({ encontrada: true, nome: result.nome, profissao: result.profissao, registro: result.registro, protocolo: result.protocolo, status: result.status, hospitais: result.hospitais, unidade_escalada: result.unidade_escalada, data_resultado: result.data_resultado });
  } catch (error) {
    console.error("consultar-resultado-plantao", error);
    return json({ message: "Não foi possível consultar o resultado agora." }, 500);
  }
});
