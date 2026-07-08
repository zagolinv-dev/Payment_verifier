import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1) Verify the caller is an authenticated manager using their JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    // Build a user-scoped client to verify the caller
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    // 2) Confirm caller is a manager (ADMIN role)
    const { data: profile } = await supabaseUser
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (!profile || profile.role !== "ADMIN") {
      return new Response(JSON.stringify({ error: "Only managers can add waiters" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 403,
      });
    }

    const managerId = user.id;

    // 3) Parse the new waiter's details
    const { fullName, email, password } = await req.json();
    if (!fullName || !email || !password) {
      return new Response(JSON.stringify({ error: "fullName, email and password are required" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    // 4) Use service-role admin client to create the auth user (bypasses email confirmation)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: created, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,   // confirmed immediately — waiter can login right away
      user_metadata: {
        full_name: fullName,
        role: "WAITRESS",
        owner_id: managerId,
      },
    });

    if (createError) throw createError;
    const newUserId = created.user.id;

    // 5) Insert/update the profiles row so the manager can see this waiter in their team list
    const { error: profileError } = await supabaseAdmin.from("profiles").upsert({
      id: newUserId,
      email,
      full_name: fullName,
      role: "WAITRESS",
      owner_id: managerId,
      status: "APPROVED",
      created_at: new Date().toISOString(),
    });

    if (profileError) throw profileError;

    return new Response(JSON.stringify({ success: true, userId: newUserId }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message ?? String(e) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
