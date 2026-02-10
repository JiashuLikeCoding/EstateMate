import { supabaseServiceClient, supabaseClientForUser } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "method_not_allowed" }), {
        status: 405,
        headers: { "content-type": "application/json" },
      });
    }

    const userClient = supabaseClientForUser(req);
    const { data: userRes, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userRes?.user) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { "content-type": "application/json" },
      });
    }

    const userId = userRes.user.id;

    const admin = supabaseServiceClient();
    const { data, error } = await admin
      .from("gmail_connections")
      .select("email")
      .eq("user_id", userId)
      .maybeSingle();

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    const email = data?.email ?? null;
    return new Response(
      JSON.stringify({ connected: !!email, email }),
      { headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
