import { createClient } from "@supabase/supabase-js";

function getAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}

// GET /api/profiles?role=ADMIN  (or other roles, or no filter for all)
export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    const role = searchParams.get("role");
    const status = searchParams.get("status");
    const excludeRole = searchParams.get("excludeRole");

    const supabaseAdmin = getAdminClient();

    let query = supabaseAdmin.from("profiles").select("*").order("created_at", { ascending: false });

    if (role) query = query.eq("role", role);
    if (status) query = query.eq("status", status);
    if (excludeRole) query = query.neq("role", excludeRole);

    const { data, error } = await query;
    if (error) throw new Error(error.message);

    const profiles = data || [];

    // Enrich waitress profiles with their cafe's company name
    // Use cafe_id if set, otherwise fall back to owner_id (for older profiles)
    const cafeIds = [...new Set(
      profiles
        .filter(p => p.role === "WAITRESS" && (p.cafe_id || p.owner_id))
        .map(p => p.cafe_id || p.owner_id)
    )];
    let cafeMap = {};
    if (cafeIds.length > 0) {
      const { data: cafes } = await supabaseAdmin
        .from("profiles")
        .select("id, owner_name, full_name")
        .in("id", cafeIds);
      if (cafes) {
        cafes.forEach(c => { cafeMap[c.id] = c.owner_name || c.full_name || "Unknown"; });
      }
    }

    const enriched = profiles.map(p => ({
      ...p,
      company_name: p.role === "WAITRESS"
        ? (cafeMap[p.cafe_id || p.owner_id] || "—")
        : (p.owner_name || p.full_name || "—"),
    }));

    return Response.json({ profiles: enriched });
  } catch (err) {
    return Response.json({ error: err.message }, { status: 500 });
  }
}
