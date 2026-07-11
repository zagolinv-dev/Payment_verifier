import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { name, email, role } = await req.json();

    if (!name || !email || !role) {
      return new Response(
        JSON.stringify({ error: "name, email, and role are required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // Use service role key so this works without authentication (unauthenticated user on login screen)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const roleLabel = role === 'manager' ? 'Manager' : 'Waiter';
    const title = `${roleLabel} Password Reset Appeal`;
    const message = `${roleLabel} ${name} (${email}) has requested a password reset.`;

    if (role === 'manager') {
      // Notify Super Admin
      const { data: superAdmin } = await supabaseAdmin
        .from('profiles')
        .select('id')
        .eq('role', 'SUPER_ADMIN')
        .limit(1)
        .maybeSingle();

      if (superAdmin) {
        await supabaseAdmin.from('notifications').insert({
          user_id: superAdmin.id,
          type: 'info',
          title,
          message,
        });
      }
    } else if (role === 'waiter') {
      // Notify Manager (via password_reset_requests table + look up their manager)
      await supabaseAdmin.from('password_reset_requests').insert({ name, email });

      // Also try to notify their cafe manager
      const { data: waiterProfile } = await supabaseAdmin
        .from('profiles')
        .select('cafe_id')
        .eq('email', email.trim())
        .maybeSingle();

      if (waiterProfile?.cafe_id) {
        await supabaseAdmin.from('notifications').insert({
          user_id: waiterProfile.cafe_id,
          type: 'info',
          title,
          message,
        });
      }
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
