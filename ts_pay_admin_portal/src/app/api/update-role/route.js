import { createClient } from "@supabase/supabase-js";

export async function POST(request) {
  try {
    const { userId, role, fullName, email, ownerName, phone, address, description, password, cafeId } = await request.json();

    if (!userId || !role) {
      return Response.json({ error: "userId and role are required" }, { status: 400 });
    }

    if (!["WAITRESS", "ADMIN"].includes(role)) {
      return Response.json({ error: "Invalid role" }, { status: 400 });
    }

    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    if (password) {
      const { error: passwordError } = await supabaseAdmin.auth.admin.updateUserById(userId, { password });
      if (passwordError) {
        return Response.json({ error: "Failed to update password: " + passwordError.message }, { status: 500 });
      }
    }

    if (email) {
      const { error: emailError } = await supabaseAdmin.auth.admin.updateUserById(userId, { email });
      if (emailError) {
        return Response.json({ error: "Failed to update email: " + emailError.message }, { status: 500 });
      }
    }

    const { data: authUser, error: authLookupError } = await supabaseAdmin.auth.admin.getUserById(userId);
    if (authLookupError) {
      return Response.json({ error: "Failed to load auth user: " + authLookupError.message }, { status: 500 });
    }

    const finalOwnerId = role === "WAITRESS" ? (cafeId || null) : (role === "ADMIN" ? userId : null);

    const currentMetadata = authUser?.user?.user_metadata || {};
    const { error: authUpdateError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
      user_metadata: {
        ...currentMetadata,
        role,
        full_name: fullName || currentMetadata.full_name,
        owner_name: ownerName || currentMetadata.owner_name,
        phone: phone || currentMetadata.phone,
        address: address || currentMetadata.address,
        description: description || currentMetadata.description,
        owner_id: finalOwnerId,
        cafe_id: finalOwnerId,
      },
    });

    if (authUpdateError) {
      return Response.json({ error: "Failed to update auth metadata: " + authUpdateError.message }, { status: 500 });
    }

    const profileUpdate = {
      role,
      full_name: fullName,
      email,
      owner_id: finalOwnerId,
      cafe_id: finalOwnerId,
    };
    if (role === "ADMIN") {
      profileUpdate.owner_name = ownerName || null;
      profileUpdate.phone = phone || null;
      profileUpdate.address = address || null;
      profileUpdate.description = description || null;
    }

    const { error } = await supabaseAdmin
      .from("profiles")
      .update(profileUpdate)
      .eq("id", userId);

    if (error) {
      return Response.json({ error: error.message }, { status: 500 });
    }

    return Response.json({ success: true });
  } catch (err) {
    return Response.json({ error: err.message }, { status: 500 });
  }
}
