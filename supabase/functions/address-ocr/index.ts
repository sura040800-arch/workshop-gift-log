import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://sura040800-arch.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return json({ error: "ログインが必要です。" }, 401);
    const projectUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!projectUrl || !anonKey) return json({ error: "Supabaseの認証設定が不足しています。" }, 500);
    const caller = createClient(projectUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await caller.auth.getUser();
    if (authError || !authData.user) return json({ error: "ログイン状態を確認できません。" }, 401);
    const { data: profile, error: profileError } = await caller
      .from("staff_profiles").select("is_active").eq("user_id", authData.user.id).maybeSingle();
    if (profileError || !profile || profile.is_active !== true) return json({ error: "利用権限を確認できません。" }, 403);

    const endpoint = Deno.env.get("AZURE_VISION_ENDPOINT")?.replace(/\/+$/, "");
    const key = Deno.env.get("AZURE_VISION_KEY");
    if (!endpoint || !key) return json({ error: "OCRサービスの設定がまだ完了していません。管理者によるAzure接続設定が必要です。" }, 503);

    const form = await req.formData();
    const file = form.get("file");
    if (!(file instanceof File) || !file.type.startsWith("image/")) return json({ error: "画像ファイルを送信してください。" }, 400);
    if (file.size > 15 * 1024 * 1024) return json({ error: "写真は15MB以下にしてください。" }, 413);
    const bytes = await file.arrayBuffer();
    const url = endpoint + "/computervision/imageanalysis:analyze?api-version=2024-02-01&features=read";
    const azure = await fetch(url, {
      method: "POST",
      headers: { "Ocp-Apim-Subscription-Key": key, "Content-Type": file.type || "application/octet-stream" },
      body: bytes,
    });
    if (!azure.ok) {
      const detail = await azure.text();
      console.error("Azure Vision OCR error", azure.status, detail.slice(0, 500));
      return json({ error: azure.status === 401 || azure.status === 403
        ? "OCRサービスの認証に失敗しました。管理者に設定確認を依頼してください。"
        : "OCRサービスで読み取りに失敗しました。時間をおいて再試行してください。" }, 502);
    }
    const result = await azure.json();
    const blocks = result?.readResult?.blocks || [];
    const lines = blocks.flatMap((block: any) => (block.lines || []).map((line: any) => ({
      text: String(line.text || ""),
      polygon: line.boundingPolygon || [],
    }))).filter((line: any) => line.text);
    if (!lines.length) return json({ error: "伝票から文字を認識できませんでした。写真を明るく撮り直してください。" }, 422);
    return json({ lines });
  } catch (error) {
    console.error("address-ocr error", error);
    return json({ error: "読み取り処理中にエラーが発生しました。" }, 500);
  }
});
