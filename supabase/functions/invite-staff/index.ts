import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://sura040800-arch.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return json({ error: "ログインが必要です。" }, 401);

    const projectUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const secretMap = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
    const secretKey = secretMap.default || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!projectUrl || !anonKey || !secretKey) {
      return json({ error: "サーバー側の認証設定が不足しています。SupabaseのEdge Function環境変数を確認してください。" }, 500);
    }

    const caller = createClient(projectUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await caller.auth.getUser();
    if (userError || !userData.user) return json({ error: "ログイン状態を確認できません。" }, 401);

    const { data: profile, error: profileError } = await caller
      .from("staff_profiles")
      .select("role,is_active")
      .eq("user_id", userData.user.id)
      .maybeSingle();
    if (profileError || !profile || profile.role !== "admin" || !profile.is_active) {
      return json({ error: "スタッフ招待は管理者のみ実行できます。" }, 403);
    }

    const body = await req.json();
    const email = String(body?.email || "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ error: "メールアドレスを正しく入力してください。" }, 400);
    }

    const admin = createClient(projectUrl, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
      redirectTo: "https://sura040800-arch.github.io/workshop-gift-log/",
    });
    if (inviteError) return json({ error: inviteError.message }, 400);
    return json({ ok: true, email: invited.user?.email || email });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "招待に失敗しました。" }, 500);
  }
});
