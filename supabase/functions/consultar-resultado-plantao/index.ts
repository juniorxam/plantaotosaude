import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, authorization, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Expose-Headers": "Retry-After",
};
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, serviceRoleKey);
const json = (body: unknown, status = 200, extraHeaders: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...extraHeaders },
  });
const digits = (value: unknown) => String(value ?? "").replace(/\D/g, "");

function validCpf(value: string) {
  if (!/^\d{11}$/.test(value) || /^([0-9])\1{10}$/.test(value)) return false;
  let sum = 0;
  for (let i = 0; i < 9; i++) sum += Number(value[i]) * (10 - i);
  let digit = (sum * 10) % 11;
  if (digit === 10) digit = 0;
  if (digit !== Number(value[9])) return false;
  sum = 0;
  for (let i = 0; i < 10; i++) sum += Number(value[i]) * (11 - i);
  digit = (sum * 10) % 11;
  if (digit === 10) digit = 0;
  return digit === Number(value[10]);
}

async function hashClientIp(ip: string) {
  const salt = Deno.env.get("RATE_LIMIT_SALT") ?? serviceRoleKey;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(salt),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`plantao-consulta:${ip}`));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ message: "Método não permitido." }, 405);

  try {
    const ip = request.headers.get("cf-connecting-ip")?.trim()
      || request.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
      || "unknown";
    const ipHash = await hashClientIp(ip);
    const { data: limitRows, error: limitError } = await supabase.rpc("consume_plantao_consulta_attempt", {
      p_ip_hash: ipHash,
    });
    if (limitError) throw limitError;
    const limit = Array.isArray(limitRows) ? limitRows[0] : limitRows;
    if (!limit) throw new Error("A verificação de limite de consultas não retornou resultado.");
    if (!limit.allowed) {
      const retryAfter = Math.max(1, Number(limit.retry_after_seconds) || 900);
      return json(
        { message: `Muitas consultas em sequência. Tente novamente em ${retryAfter} segundos.` },
        429,
        { "Retry-After": String(retryAfter) },
      );
    }

    const body = request.headers.get("content-type")?.includes("application/json")
      ? await request.json()
      : await request.formData();
    const cpf = digits(body instanceof FormData ? body.get("cpf") : body?.cpf);
    if (!validCpf(cpf)) return json({ message: "Informe um CPF válido." }, 400);

    const { data, error } = await supabase.rpc("consultar_resultado_plantao", { p_cpf: cpf });
    if (error) throw error;
    const result = Array.isArray(data) ? data[0] : data;
    if (!result) return json({ encontrada: false });
    return json({
      encontrada: true,
      nome: result.nome,
      profissao: result.profissao,
      registro: result.registro,
      protocolo: result.protocolo,
      status: result.status,
      hospitais: result.hospitais,
      unidade_escalada: result.unidade_escalada,
      plantao_escalado: result.plantao_escalado,
      valor_pagamento: result.valor_pagamento,
      data_resultado: result.data_resultado,
    });
  } catch (error) {
    console.error("consultar-resultado-plantao", error);
    return json({ message: "Não foi possível consultar agora. Tente novamente em instantes." }, 500);
  }
});
