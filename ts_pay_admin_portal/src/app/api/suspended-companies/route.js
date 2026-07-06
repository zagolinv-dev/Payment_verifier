import { createClient } from "@supabase/supabase-js";

function getAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}

// GET /api/suspended-companies
// Returns all profiles with role ADMIN that are suspended
export async function GET(request) {
  try {
    const supabaseAdmin = getAdminClient();
    const { data, error } = await supabaseAdmin
      .from("profiles")
      .select("*")
      .eq("role", "ADMIN")
      .eq("status", "SUSPENDED")
      .order("created_at", { ascending: false });
    if (error) throw new Error(error.message);
    return Response.json({ companies: data || [] });
  } catch (err) {
    return Response.json({ error: err.message }, { status: 500 });
  }
}
