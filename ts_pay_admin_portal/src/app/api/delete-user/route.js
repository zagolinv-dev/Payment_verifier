import { createClient } from "@supabase/supabase-js";

    export async function POST(request) {
    try {
      const { userId } = await request.json();

      if (!userId) {
        return Response.json({ error: "userId is required" }, { status: 400 });
      }

      const supabaseAdmin = createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL,
        process.env.SUPABASE_SERVICE_ROLE_KEY,
        { auth: { autoRefreshToken: false, persistSession: false } }
      );

      // Attempt to delete auth user first
      const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(userId);
      const authNotFound = authError && authError.code === "user_not_found";
      if (authError && !authNotFound) {
        console.error("Auth deletion error:", authError);
        // Continue to attempt profile deletion even if auth fails
      }

      // Delete profile record
      const { error: profileError } = await supabaseAdmin
        .from("profiles")
        .delete()
        .eq("id", userId);
      if (profileError) {
        console.error("Profile deletion error:", profileError);
        return Response.json({ error: "Failed to delete profile: " + profileError.message }, { status: 500 });
      }

      // If auth deletion also failed (and not due to not‑found), inform the client
      if (authError && !authNotFound) {
        return Response.json({ warning: "Auth user could not be deleted, but profile removed.", success: true }, { status: 200 });
      }

      return Response.json({ success: true });
    } catch (err) {
      console.error("Unexpected error:", err);
      return Response.json({ error: err.message }, { status: 500 });
    }
  }
