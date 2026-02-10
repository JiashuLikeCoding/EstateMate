import { supabaseServiceClient, requireUser } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "method_not_allowed" }), {
        status: 405,
        headers: { "content-type": "application/json" },
      });
    }

    const { user, errorResponse } = await requireUser(req);
    if (errorResponse) return errorResponse;

    const userId = user!.id;

    const admin = supabaseServiceClient();
    const { error } = await admin.from("gmail_connections").delete().eq("user_id", userId);
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
