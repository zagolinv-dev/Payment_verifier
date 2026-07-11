import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const { fullName, email, password, ownerId } = await req.json();

    if (!email || !password || !fullName || !ownerId) {
      return new Response(
        JSON.stringify({ error: "Email, password, name, and ownerId are required" }),
        { headers: { "Content-Type": "application/json" }, status: 400 }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: userData, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        role: "WAITRESS",
        owner_id: ownerId,
        cafe_id: ownerId,
      },
    });

    if (createError) {
      return new Response(
        JSON.stringify({ error: createError.message }),
        { headers: { "Content-Type": "application/json" }, status: 500 }
      );
    }

    const { error: profileError } = await supabaseAdmin
      .from("profiles")
      .upsert({
        id: userData.user.id,
        email,
        full_name: fullName,
        role: "WAITRESS",
        status: "APPROVED",
        owner_id: ownerId,
        cafe_id: ownerId,
      });

    if (profileError) {
      return new Response(
        JSON.stringify({ error: "User created but profile update failed: " + profileError.message }),
        { headers: { "Content-Type": "application/json" }, status: 500 }
      );
    }

    return new Response(
      JSON.stringify({ success: true, userId: userData.user.id }),
      { headers: { "Content-Type": "application/json" }, status: 200 }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { headers: { "Content-Type": "application/json" }, status: 500 }
    );
  }
});
