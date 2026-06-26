import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const { fullName, phone, ownerName, address, description } = await req.json();

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const timestamp = Date.now();
    const placeholderEmail = `pending-${timestamp}@temp.tspay`;
    const tempPassword = `Temp${timestamp}@Tspay`;

    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email: placeholderEmail,
      password: tempPassword,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        role: "ADMIN",
        phone,
        owner_name: ownerName,
        address,
        description,
      },
    });

    if (error) throw error;

    const { error: profileError } = await supabaseAdmin.from("profiles").upsert({
      id: data.user.id,
      email: placeholderEmail,
      full_name: fullName,
      role: "ADMIN",
      status: "PENDING",
      phone,
      owner_name: ownerName,
      address,
      description,
    });

    if (profileError) throw profileError;

    return new Response(JSON.stringify({ success: true, userId: data.user.id }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
