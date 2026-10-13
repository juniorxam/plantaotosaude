import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "apikey, authorization, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const hospitals = new Set(["Palmas — Hospital Geral de Palmas","Araguaína — Hospital Regional de Araguaína","Gurupi — Hospital Regional de Gurupi","Paraíso do Tocantins — Hospital Regional de Paraíso","Porto Nacional — Hospital Regional de Porto Nacional","Augustinópolis — Hospital Regional de Augustinópolis"]);
const shifts = new Set(["A — Véspera, noturno — 31/10/2026, 19h às 7h de 01/11","B — Dia do concurso, diurno — 01/11/2026, 7h às 19h","C — Dia do concurso, noturno — 01/11/2026, 19h às 7h de 02/11"]);
const professions = new Set(["Médico","Enfermeiro","Técnico em Enfermagem","Fisioterapeuta","Nutricionista","Psicólogo","Farmacêutico","Assistente Social","Técnico em Radiologia","Técnico em Laboratório","Outro"]);
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
const digits = (value: FormDataEntryValue | null) => String(value ?? "").replace(/\D/g, "");
function validCpf(value: string) {
  if (!/^\d{11}$/.test(value) || /^([0-9])\1{10}$/.test(value)) return false;
  let sum = 0; for (let i = 0; i < 9; i++) sum += Number(value[i]) * (10 - i);
  let digit = (sum * 10) % 11; if (digit === 10) digit = 0; if (digit !== Number(value[9])) return false;
  sum = 0; for (let i = 0; i < 10; i++) sum += Number(value[i]) * (11 - i);
  digit = (sum * 10) % 11; if (digit === 10) digit = 0;
  return digit === Number(value[10]);
}
async function hash(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ message: "Método não permitido." }, 405);
  let uploadedPath = "";
  try {
    const form = await request.formData();
    if (String(form.get("website") ?? "").trim() || Date.now() - Number(form.get("form_started_at") ?? 0) < 2500) return json({ message: "Não foi possível processar a inscrição." }, 400);
    const file = form.get("curriculo");
    if (!(file instanceof File) || file.size === 0 || file.size > 5 * 1024 * 1024) return json({ message: "Anexe um currículo de até 5 MB." }, 400);
    const mimeMap: Record<string,string> = { pdf:"application/pdf", doc:"application/msword", docx:"application/vnd.openxmlformats-officedocument.wordprocessingml.document" };
    const ext = file.name.toLowerCase().match(/\.([a-z0-9]+)$/)?.[1] ?? "";
    if (!mimeMap[ext] || file.type !== mimeMap[ext]) return json({ message: "O currículo deve estar em PDF, DOC ou DOCX." }, 400);
    const nome = String(form.get("nome") ?? "").trim(), cpf = digits(form.get("cpf")), nascimento = String(form.get("nascimento") ?? "");
    const telefone = String(form.get("telefone") ?? "").trim(), email = String(form.get("email") ?? "").trim().toLowerCase();
    const profissao = String(form.get("profissao") ?? "").trim(), registro = String(form.get("registro") ?? "").trim();
    const servidorEstadoRaw = String(form.get("servidor_estado") ?? "");
    const servidorEstado = servidorEstadoRaw === "true" ? true : servidorEstadoRaw === "false" ? false : null;
    const observacoes = String(form.get("observacoes") ?? "").trim().slice(0,2000), declaracao = form.get("declaracao") === "true";
    let selectedHospitals: string[], selectedShifts: string[];
    try { selectedHospitals = JSON.parse(String(form.get("hospitais") ?? "[]")); selectedShifts = JSON.parse(String(form.get("plantoes") ?? "[]")); } catch { return json({ message: "Seleções inválidas." }, 400); }
    const today = new Date().toISOString().slice(0,10);
    if (nome.length < 5 || nome.length > 150 || !validCpf(cpf) || !/^\d{4}-\d{2}-\d{2}$/.test(nascimento) || nascimento < "1900-01-01" || nascimento > today || digits(telefone).length < 10 || digits(telefone).length > 15 || email.length < 5 || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !professions.has(profissao) || registro.length < 2 || registro.length > 100 || servidorEstado === null || !declaracao || !Array.isArray(selectedHospitals) || selectedHospitals.length < 1 || selectedHospitals.length > 6 || !Array.isArray(selectedShifts) || selectedShifts.length < 1 || selectedShifts.length > 3 || selectedHospitals.some((v) => !hospitals.has(v)) || selectedShifts.some((v) => !shifts.has(v)) || new Set(selectedHospitals).size !== selectedHospitals.length || new Set(selectedShifts).size !== selectedShifts.length) return json({ message: "Confira os dados da inscrição e tente novamente." }, 400);
    const ip = request.headers.get("cf-connecting-ip") ?? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const ipHash = await hash(ip + ":" + (Deno.env.get("RATE_LIMIT_SALT") ?? "plantao-to-saude"));
    const { data: last } = await supabase.from("submission_rate_limits").select("last_submitted_at").eq("ip_hash",ipHash).maybeSingle();
    if (last && Date.now() - new Date(last.last_submitted_at).getTime() < 60000) return json({ message: "Aguarde um minuto antes de enviar outra inscrição." },429);
    uploadedPath = "curriculos/" + crypto.randomUUID() + "." + ext;
    const upload = await supabase.storage.from("curriculos").upload(uploadedPath,file,{contentType:mimeMap[ext],upsert:false});
    if (upload.error) throw upload.error;
    const { data, error } = await supabase.rpc("register_plantao_inscricao",{p_nome:nome,p_cpf:cpf,p_nascimento:nascimento,p_telefone:telefone,p_email:email,p_profissao:profissao,p_registro:registro,p_hospitais:selectedHospitals,p_plantoes:selectedShifts,p_servidor_estado:servidorEstado,p_observacoes:observacoes || null,p_curriculo_path:uploadedPath});
    if (error) {
      if (error.code === "23505" || String(error.message).includes("Já existe uma inscrição")) { await supabase.storage.from("curriculos").remove([uploadedPath]); uploadedPath = ""; return json({ message: "Este CPF já possui uma inscrição registrada." },409); }
      throw error;
    }
    await supabase.from("submission_rate_limits").upsert({ip_hash:ipHash,last_submitted_at:new Date().toISOString()});
    const protocol = Array.isArray(data) ? data[0]?.protocolo : data?.protocolo;
    uploadedPath = "";
    return json({ protocolo: protocol });
  } catch (error) {
    if (uploadedPath) await supabase.storage.from("curriculos").remove([uploadedPath]).catch(() => undefined);
    console.error("submit-plantao-inscricao",error);
    return json({ message: "Não foi possível concluir a inscrição agora. Tente novamente." },500);
  }
});