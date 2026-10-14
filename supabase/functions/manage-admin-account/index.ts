import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function reply(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Método não permitido." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !serviceKey || !anonKey) {
    return reply({ error: "Configuração do servidor incompleta." }, 500);
  }

  const authorization = req.headers.get("Authorization") || "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) return reply({ error: "Sessão necessária." }, 401);

  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: authData, error: authError } = await callerClient.auth.getUser(token);
  const caller = authData?.user;
  if (authError || !caller?.email) return reply({ error: "Sessão inválida ou expirada." }, 401);
  const callerEmail = caller.email.trim().toLowerCase();

  let body: { action?: string; email?: string; password?: string };
  try { body = await req.json(); } catch { return reply({ error: "Requisição inválida." }, 400); }

  if (body.action === "complete-first-access") {
    const password = body.password || "";
    if (password.length < 10 || password.length > 128 || password === "123456") {
      return reply({ error: "Crie uma senha com pelo menos 10 caracteres, diferente da senha temporária." }, 400);
    }
    const { data: ownAuth, error: ownAuthError } = await admin.auth.admin.getUserById(caller.id);
    if (ownAuthError || ownAuth?.user?.app_metadata?.must_change_password !== true) {
      return reply({ error: "Esta conta não está aguardando a troca inicial de senha." }, 403);
    }
    const { data: ownAccess, error: accessError } = await admin
      .from("admin_users").select("email,ativo").eq("email", callerEmail).maybeSingle();
    if (accessError || !ownAccess) return reply({ error: "Acesso administrativo não foi preparado." }, 403);

    const { error: activateError } = await admin.from("admin_users")
      .update({ ativo: true }).eq("email", callerEmail);
    if (activateError) return reply({ error: "Não foi possível concluir a ativação. Tente novamente." }, 500);

    const metadata = { ...(ownAuth.user.app_metadata || {}), must_change_password: false };
    const { error: updateError } = await admin.auth.admin.updateUserById(caller.id, {
      password,
      app_metadata: metadata,
      ban_duration: "none",
    });
    if (updateError) {
      await admin.from("admin_users").update({ ativo: false }).eq("email", callerEmail);
      return reply({ error: "Não foi possível salvar a nova senha. Tente novamente." }, 500);
    }
    await admin.from("admin_audit_log").insert({
      actor_email: callerEmail, action: "FIRST_PASSWORD_SET", entity: "admin_users",
      entity_id: callerEmail, details: { first_access_completed: true },
    });
    return reply({ ok: true });
  }

  const { data: callerAccess, error: callerAccessError } = await admin
    .from("admin_users").select("ativo").eq("email", callerEmail).maybeSingle();
  if (callerAccessError || callerAccess?.ativo !== true) {
    return reply({ error: "Somente administradores ativos podem gerenciar acessos." }, 403);
  }

  const targetEmail = (body.email || "").trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(targetEmail) || targetEmail.length > 254) {
    return reply({ error: "Informe um e-mail válido." }, 400);
  }

  if (body.action === "grant") {
    let targetUser: any = null;
    for (let page = 1; page <= 10 && !targetUser; page++) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
      if (error) return reply({ error: "Não foi possível consultar as contas de autenticação." }, 500);
      targetUser = data.users.find((u) => u.email?.toLowerCase() === targetEmail) || null;
      if (data.users.length < 1000) break;
    }

    if (targetUser) {
      const { error } = await admin.auth.admin.updateUserById(targetUser.id, {
        password: "123456",
        email_confirm: true,
        app_metadata: { ...(targetUser.app_metadata || {}), must_change_password: true },
        ban_duration: "none",
      });
      if (error) return reply({ error: "Não foi possível preparar a conta de autenticação." }, 500);
    } else {
      const { error } = await admin.auth.admin.createUser({
        email: targetEmail, password: "123456", email_confirm: true,
        app_metadata: { must_change_password: true },
      });
      if (error) return reply({ error: "Não foi possível criar a conta. Verifique se o e-mail já existe." }, 400);
    }

    const { error: upsertError } = await admin.from("admin_users").upsert(
      { email: targetEmail, ativo: false }, { onConflict: "email" },
    );
    if (upsertError) return reply({ error: "A conta foi preparada, mas não foi possível registrar o acesso. Contate a administração." }, 500);

    await admin.from("admin_audit_log").insert({
      actor_email: callerEmail, action: "GRANT_PENDING", entity: "admin_users",
      entity_id: targetEmail, details: { ativo: false, must_change_password: true },
    });
    return reply({ ok: true, pending: true, email: targetEmail });
  }

  if (body.action === "revoke") {
    if (targetEmail === callerEmail) return reply({ error: "Você não pode remover o próprio acesso." }, 400);
    const { error: rowError } = await admin.from("admin_users")
      .upsert({ email: targetEmail, ativo: false }, { onConflict: "email" });
    if (rowError) return reply({ error: "Não foi possível desativar o acesso." }, 500);

    let targetUser: any = null;
    for (let page = 1; page <= 10 && !targetUser; page++) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
      if (error) return reply({ error: "Acesso desativado no painel, mas não foi possível bloquear a sessão de autenticação." }, 500);
      targetUser = data.users.find((u) => u.email?.toLowerCase() === targetEmail) || null;
      if (data.users.length < 1000) break;
    }
    if (targetUser) {
      const { error } = await admin.auth.admin.updateUserById(targetUser.id, { ban_duration: "876000h" });
      if (error) return reply({ error: "Acesso desativado, mas não foi possível bloquear a autenticação." }, 500);
    }
    await admin.from("admin_audit_log").insert({
      actor_email: callerEmail, action: "REVOKE", entity: "admin_users",
      entity_id: targetEmail, details: { ativo: false },
    });
    return reply({ ok: true, active: false });
  }

  return reply({ error: "Ação não reconhecida." }, 400);
});
