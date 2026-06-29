import { createClient } from "@supabase/supabase-js";

export async function POST(request) {
  try {
    const { email, password, fullName, role, phone, ownerName, address, description } = await request.json();

    if (!email || !password || !fullName) {
      return Response.json({ error: "Email, password, and name are required" }, { status: 400 });
    }

    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    const { data: userData, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        role: role || "WAITRESS",
        phone: phone || null,
        owner_name: ownerName || null,
        address: address || null,
        description: description || null,
      },
    });

    if (createError) {
      return Response.json({ error: createError.message }, { status: 500 });
    }

    const { error: profileError } = await supabaseAdmin
      .from("profiles")
      .upsert({
        id: userData.user.id,
        email,
        full_name: fullName,
        role: role || "WAITRESS",
        status: "APPROVED",
        phone: phone || null,
        owner_name: ownerName || null,
        address: address || null,
        description: description || null,
      });

    if (profileError) {
      return Response.json({ error: "User created but profile update failed: " + profileError.message }, { status: 500 });
    }

    return Response.json({ success: true, userId: userData.user.id });
  } catch (err) {
    return Response.json({ error: err.message }, { status: 500 });
  }
}
