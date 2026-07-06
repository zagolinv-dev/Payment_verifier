import { createClient } from "@supabase/supabase-js";

// Service-role client — bypasses RLS, sees all data
function getAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}

export async function GET() {
  try {
    const supabaseAdmin = getAdminClient();

    const [txResult, profileCountResult] = await Promise.all([
      supabaseAdmin.from("transactions").select("*"),
      supabaseAdmin.from("profiles").select("id", { count: "exact", head: true }),
    ]);

    if (txResult.error) throw new Error(txResult.error.message);

    const txns = txResult.data || [];
    const totalAmount = txns.reduce((s, t) => s + (Number(t.amount) || 0), 0);
    const verifiedCount = txns.filter((t) => t.status === "VERIFIED").length;
    const failedCount = txns.filter((t) => t.status === "FAILED").length;
    const pendingCount = txns.filter((t) => t.status === "PENDING").length;

    // Build 7-day chart data
    const days = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const dayStr = d.toISOString().slice(0, 10);
      const dayTxns = txns.filter((t) => t.created_at?.startsWith(dayStr));
      days.push({
        name: d.toLocaleDateString("en-US", { weekday: "short" }),
        total: dayTxns.reduce((s, t) => s + (Number(t.amount) || 0), 0),
        count: dayTxns.length,
        verified: dayTxns.filter((t) => t.status === "VERIFIED").length,
        pending: dayTxns.filter((t) => t.status === "PENDING").length,
        failed: dayTxns.filter((t) => t.status === "FAILED").length,
      });
    }

    return Response.json({
      metrics: {
        totalAmount,
        totalTransactions: txns.length,
        pendingCount,
        verifiedCount,
        failedCount,
        userCount: profileCountResult.count || 0,
      },
      weeklyData: days,
    });
  } catch (err) {
    return Response.json({ error: err.message }, { status: 500 });
  }
}
