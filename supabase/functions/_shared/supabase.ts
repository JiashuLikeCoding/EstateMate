// Shared Supabase client helpers for Edge Functions
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function env(name: string) {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

export function supabaseClientForUser(req: Request) {
  const supabaseUrl = env("SUPABASE_URL");
  const anonKey = env("SUPABASE_ANON_KEY");
  const authHeader = req.headers.get("Authorization") ?? "";

  return createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
  });
}

export async function requireUser(req: Request) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";

  if (!token) {
    return {
      user: null,
      errorResponse: new Response(
        JSON.stringify({ code: 401, message: "Missing Authorization Bearer token" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      ),
    };
  }

  const supabase = supabaseClientForUser(req);
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data?.user) {
    return {
      user: null,
      errorResponse: new Response(
        JSON.stringify({
          code: 401,
          message: "Invalid or expired session",
          details: error?.message ?? null,
        }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      ),
    };
  }

  return { user: data.user, errorResponse: null };
}

export function supabaseServiceClient() {
  const supabaseUrl = env("SUPABASE_URL");
  const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
  return createClient(supabaseUrl, serviceKey);
}
