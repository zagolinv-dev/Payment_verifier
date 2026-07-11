import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { email, newPassword } = await req.json();

    if (!email || !newPassword) {
      return new Response(
        JSON.stringify({ error: "Email and newPassword are required" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Missing Authorization header" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid token" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 401 }
      );
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Get caller profile
    const { data: callerProfile, error: callerError } = await supabaseAdmin
      .from('profiles')
      .select('role, id')
      .eq('id', user.id)
      .single();

    if (callerError || !callerProfile) {
      return new Response(
        JSON.stringify({ error: "Caller profile not found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
      );
    }

    // Get target profile
    const { data: targetProfile, error: targetError } = await supabaseAdmin
      .from('profiles')
      .select('id, cafe_id, role')
      .eq('email', email.trim())
      .single();

    if (targetError || !targetProfile) {
      return new Response(
        JSON.stringify({ error: "Target user not found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 404 }
      );
    }

    // Check permissions
    if (callerProfile.role !== 'SUPER_ADMIN') {
      if (callerProfile.role !== 'ADMIN') {
        return new Response(
          JSON.stringify({ error: "Permission denied: You must be an ADMIN or SUPER_ADMIN" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
        );
      }
      // If ADMIN, can only reset Waiters inside their own cafe
      if (targetProfile.role !== 'WAITRESS' || targetProfile.cafe_id !== callerProfile.id) {
        return new Response(
          JSON.stringify({ error: "Permission denied: User does not belong to your cafe or is not a waitress" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 403 }
        );
      }
    }

    // Update password
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(targetProfile.id, { 
      password: newPassword 
    });

    if (updateError) {
      return new Response(
        JSON.stringify({ error: updateError.message }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
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
