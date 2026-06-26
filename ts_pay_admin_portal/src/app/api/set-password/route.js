import { createClient } from "@supabase/supabase-js";

export async function POST(request) {
  try {
    const { userId, email, password, fullName, phone, ownerName, address, description } = await request.json();

    if (!userId) {
      return Response.json({ error: "User ID is required" }, { status: 400 });
    }
    if (!email || !email.includes("@")) {
      return Response.json({ error: "Valid email is required" }, { status: 400 });
    }
    if (!password || password.length < 6) {
      return Response.json({ error: "Password must be at least 6 characters" }, { status: 400 });
    }

    const supabaseAdmin = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    let authUserId = userId;

    // Try to create the user (handles pending applications with no auth user yet)
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName || null,
        role: "ADMIN",
        phone: phone || null,
        owner_name: ownerName || null,
        address: address || null,
        description: description || null,
      },
    });

    if (createError) {
      if (createError.message?.includes("already exists") || createError.message?.includes("duplicate")) {
        // User already exists — just update email + password
        const { error: emailError } = await supabaseAdmin.auth.admin.updateUserById(userId, { email });
        if (emailError) {
          return Response.json({ error: "Failed to update email: " + emailError.message }, { status: 500 });
        }
        const { error: passwordError } = await supabaseAdmin.auth.admin.updateUserById(userId, { password });
        if (passwordError) {
          return Response.json({ error: "Failed to set password: " + passwordError.message }, { status: 500 });
        }
      } else {
        return Response.json({ error: "Failed to create user: " + createError.message }, { status: 500 });
      }
    } else {
      // New user was created — use the new auth ID, delete old pending profile
      authUserId = newUser.user.id;
      await supabaseAdmin.from("profiles").delete().eq("id", userId);
    }

    // Update profile status to APPROVED
    const { error: profileError } = await supabaseAdmin
      .from("profiles")
      .update({ status: "APPROVED", role: "ADMIN", email })
      .eq("id", authUserId);

    if (profileError) {
      return Response.json({ error: "Failed to approve profile: " + profileError.message }, { status: 500 });
    }

    return Response.json({ success: true, userId: authUserId });
  } catch (err) {
    return Response.json({ error: err.message }, { status: 500 });
  }
}
