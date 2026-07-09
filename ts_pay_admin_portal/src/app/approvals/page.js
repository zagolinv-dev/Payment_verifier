"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { CheckCircleIcon, XCircleIcon, ShieldIcon, EyeIcon } from "@/components/Icons";
import DashboardLayout from "../dashboard-layout";

export default function ApprovalsPage() {
  const [merchants, setMerchants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [darkMode, setDarkMode] = useState(() => typeof window !== "undefined" ? JSON.parse(localStorage.getItem("adminDarkMode") ?? "false") : false);
  const [reviewing, setReviewing] = useState(null);
  const [selected, setSelected] = useState(null);
  const [approveEmail, setApproveEmail] = useState("");
  const [approvePassword, setApprovePassword] = useState("");
  const [toast, setToast] = useState({ message: "", type: "info" });
  const [settingPassword, setSettingPassword] = useState(false);
  const [approvedMerchant, setApprovedMerchant] = useState(null);

  useEffect(() => {
    const loadMerchants = async () => {
      try {
        const { data } = await supabase.from("profiles").select("*").eq("status", "PENDING");
        setMerchants(data || []);
      } catch (err) { console.error("Failed to load merchants:", err); }
      finally { setLoading(false); }
    };
    loadMerchants();
  }, []);

  const showToast = (message, type = "success") => {
    setToast({ message, type });
    setTimeout(() => setToast({ message: "", type: "info" }), 4000);
  };

  const handleApprove = async (id, merchant) => {
    if (!approveEmail || !approvePassword) {
      showToast("Please enter both email and password for the merchant.", "error");
      return;
    }
    if (approvePassword.length < 6) {
      showToast("The Password must be at least 6 characters.", "error");
      return;
    }

    setSettingPassword(true);
    try {
      const res = await fetch("/api/set-password", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: id,
          email: approveEmail,
          password: approvePassword,
          fullName: merchant.full_name,
          phone: merchant.phone,
          ownerName: merchant.owner_name,
          address: merchant.address,
          description: merchant.description,
        }),
      });
      const result = await res.json();
      if (!res.ok) {
        showToast("Failed: " + (result.error || "unknown error,lets try again"), "error");
        setSettingPassword(false);
        return;
      }

      const newUserId = result.userId;
      setMerchants((prev) => prev.filter((m) => m.id !== id && m.id !== newUserId));
      setApprovedMerchant({ name: merchant.full_name, email: approveEmail, password: approvePassword });
    } catch (err) {
      showToast("Request failed: " + err.message, "error");
      setSettingPassword(false);
      return;
    }

    setReviewing(null);
    setApproveEmail("");
    setApprovePassword("");
    setSettingPassword(false);
  };

  const handleReject = async (id) => {
    const { error } = await supabase.from("profiles").update({ status: "REJECTED" }).eq("id", id);
    if (error) { showToast(error.message, "error"); return; }
    setMerchants((prev) => prev.filter((m) => m.id !== id));
    showToast("Merchant request rejected.", "error");
    setReviewing(null);
  };

  if (loading) {
    return (
      <DashboardLayout darkMode={darkMode} setDarkMode={setDarkMode}>
        <div className="flex items-center justify-center h-64">
          <div className="flex flex-col items-center gap-3">
            <div className="flex gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "0ms" }} />
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "150ms" }} />
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "300ms" }} />
            </div>
            <span className="text-xs font-medium text-zinc-500">Loading approvals...</span>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout darkMode={darkMode} setDarkMode={setDarkMode}>
      <div className="space-y-6 animate-scaleIn">
        <div>
          <h1 className={`text-xl sm:text-2xl font-bold tracking-tight ${darkMode ? "text-white" : "text-zinc-900"}`}>
            Merchant Approvals
          </h1>
          <p className={`text-xs mt-1 ${darkMode ? "text-zinc-500" : "text-zinc-500"}`}>
            Review, call the applicant, confirm payment, then approve
          </p>
        </div>

        {toast.message && (
          <div className={`flex items-center gap-3 border px-5 py-4 rounded-xl animate-scaleIn ${
            toast.type === "success" ? "bg-emerald-500/10 border-emerald-500/20 text-emerald-400" :
            toast.type === "error" ? "bg-rose-500/10 border-rose-500/20 text-rose-400" :
            "bg-amber-500/10 border-amber-500/20 text-amber-400"
          }`}>
            {toast.type === "success" ? <CheckCircleIcon className="w-5 h-5 flex-shrink-0" /> : <XCircleIcon className="w-5 h-5 flex-shrink-0" />}
            <span className="text-sm font-semibold">{toast.message}</span>
          </div>
        )}

        {merchants.length === 0 ? (
          <div className={`relative overflow-hidden rounded-2xl p-12 text-center border transition-all ${
            darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
          }`}>
            <div className="w-14 h-14 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
              <ShieldIcon className="w-7 h-7" />
            </div>
            <h3 className={`text-base font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>No pending approvals</h3>
            <p className={`text-xs mt-2 ${darkMode ? "text-zinc-500" : "text-zinc-500"}`}>All applications have been reviewed.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4">
            {merchants.map((m) => (
              <div key={m.id} className={`group relative overflow-hidden rounded-2xl p-5 sm:p-6 border transition-all duration-300 ${
                darkMode
                  ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06] hover:border-amber-500/30"
                  : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm hover:border-amber-500/30 hover:shadow-md"
              }`}>
                <div className={`absolute top-0 right-0 w-40 h-40 rounded-full blur-3xl pointer-events-none opacity-0 group-hover:opacity-40 transition-opacity ${
                  darkMode ? "bg-amber-500/5" : "bg-amber-500/3"
                }`} />
                <div className="relative flex flex-col md:flex-row md:items-center justify-between gap-5">
                  <div className="space-y-2.5 flex-1">
                    <div className="flex items-center gap-3">
                      <div className={`w-10 h-10 rounded-xl flex items-center justify-center text-sm font-bold ${
                        darkMode ? "bg-amber-500/10 text-amber-400" : "bg-amber-100 text-amber-600"
                      }`}>
                        {(m.full_name || "?")[0]}
                      </div>
                      <div>
                        <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>{m.full_name || "Unnamed"}</h3>
                        <div className="flex items-center gap-2 mt-0.5">
                          <span className="bg-amber-500/10 text-amber-500 text-[9px] font-extrabold px-2 py-0.5 rounded-full uppercase tracking-wider border border-amber-500/20">
                            Pending
                          </span>
                          <span className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{m.phone || "No phone"}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <button
                      onClick={() => setSelected(m)}
                      className="px-4 py-2.5 rounded-xl bg-white/5 text-zinc-400 border border-white/10 hover:bg-white/10 hover:text-zinc-200 font-bold text-xs transition-all cursor-pointer flex items-center gap-1.5"
                      title="View details"
                    >
                      <EyeIcon className="w-3.5 h-3.5" />
                      Details
                    </button>
                    <button
                      onClick={() => handleReject(m.id)}
                      className="px-5 py-2.5 rounded-xl bg-rose-500/10 text-rose-400 border border-rose-500/20 hover:bg-rose-500/20 font-bold text-xs transition-all cursor-pointer"
                    >
                      Reject
                    </button>
                    <button
                      onClick={() => setReviewing(reviewing === m.id ? null : m.id)}
                      className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 hover:from-emerald-400 hover:to-emerald-500 text-xs font-bold shadow-lg shadow-emerald-500/20 transition-all cursor-pointer"
                    >
                      Approve
                    </button>
                  </div>
                </div>

                {reviewing === m.id && (
                  <div className={`mt-4 pt-4 border-t ${darkMode ? "border-white/[0.06]" : "border-black/5"} animate-scaleIn space-y-3`}>
                    <p className={`text-[11px] font-semibold ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>
                      After payment is confirmed, set the login credentials for the merchant:
                    </p>
                    <input
                      type="email"
                      value={approveEmail}
                      onChange={(e) => setApproveEmail(e.target.value)}
                      placeholder="Email for merchant login"
                      className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${
                        darkMode
                          ? "bg-white/5 border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50"
                          : "bg-black/5 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"
                      }`}
                    />
                    <input
                      type="text"
                      value={approvePassword}
                      onChange={(e) => setApprovePassword(e.target.value)}
                      placeholder="Password (min 6 characters)"
                      className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${
                        darkMode
                          ? "bg-white/5 border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50"
                          : "bg-black/5 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"
                      }`}
                    />
                    <button
                      onClick={() => handleApprove(m.id, m)}
                      disabled={settingPassword}
                      className="w-full py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 hover:from-emerald-400 hover:to-emerald-500 text-xs font-bold shadow-lg shadow-emerald-500/20 transition-all cursor-pointer disabled:opacity-50"
                    >
                      {settingPassword ? "Setting up account..." : "Confirm Approve & Set Credentials"}
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Detail Modal */}
      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4" onClick={() => setSelected(null)}>
          <div
            className={`relative w-full max-w-lg rounded-2xl overflow-hidden border shadow-2xl animate-scaleIn ${
              darkMode ? "bg-[#0F1626] border-white/[0.06]" : "bg-white border-black/5"
            }`}
            onClick={(e) => e.stopPropagation()}
          >
            <div className={`px-6 py-4 border-b flex items-center justify-between ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
              <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Applicant Details</h3>
              <button
                onClick={() => setSelected(null)}
                className={`p-1 rounded-lg transition-colors cursor-pointer ${darkMode ? "text-zinc-500 hover:text-white hover:bg-white/5" : "text-zinc-400 hover:text-zinc-900 hover:bg-zinc-100"}`}
              >
                <XCircleIcon className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div className="flex items-center gap-4">
                <div className={`w-14 h-14 rounded-xl flex items-center justify-center text-xl font-bold ${
                  darkMode ? "bg-amber-500/10 text-amber-400" : "bg-amber-100 text-amber-600"
                }`}>
                  {(selected.full_name || "?")[0]}
                </div>
                <div>
                  <h4 className={`text-base font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>{selected.full_name || "Unnamed"}</h4>
                  <span className="bg-amber-500/10 text-amber-500 text-[9px] font-extrabold px-2 py-0.5 rounded-full uppercase tracking-wider border border-amber-500/20">
                    PENDING
                  </span>
                </div>
              </div>

              <div className={`grid grid-cols-2 gap-4 p-4 rounded-xl ${darkMode ? "bg-white/[0.03]" : "bg-zinc-50"}`}>
                <DetailField label="Company" value={selected.full_name || "—"} darkMode={darkMode} />
                <DetailField label="Owner" value={selected.owner_name || "—"} darkMode={darkMode} />
                <DetailField label="Phone" value={selected.phone || "—"} darkMode={darkMode} />
                <DetailField label="Address" value={selected.address || "—"} darkMode={darkMode} />
                <div className="col-span-2">
                  <DetailField label="Description" value={selected.description || "—"} darkMode={darkMode} />
                </div>
                <DetailField label="Applied" value={new Date(selected.created_at).toLocaleDateString()} darkMode={darkMode} />
              </div>

              <div className={`p-4 rounded-xl border ${darkMode ? "bg-amber-500/5 border-amber-500/10" : "bg-amber-50 border-amber-200"}`}>
                <p className={`text-xs font-semibold ${darkMode ? "text-amber-300" : "text-amber-700"}`}>
                  Call the applicant at {selected.phone || "this number"} to confirm payment before approving.
                </p>
              </div>
            </div>
            <div className={`px-6 py-4 border-t flex justify-end gap-3 ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
              <button
                onClick={() => { setSelected(null); handleReject(selected.id); }}
                className="px-5 py-2.5 rounded-xl bg-rose-500/10 text-rose-400 border border-rose-500/20 hover:bg-rose-500/20 font-bold text-xs transition-all cursor-pointer"
              >
                Reject
              </button>
              <button
                onClick={() => { setSelected(null); setReviewing(selected.id); }}
                className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 hover:from-emerald-400 hover:to-emerald-500 text-xs font-bold shadow-lg shadow-emerald-500/20 transition-all cursor-pointer"
              >
                Approve
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Success Modal with Credentials */}
      {approvedMerchant && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className={`relative w-full max-w-md rounded-2xl overflow-hidden border shadow-2xl animate-scaleIn ${
            darkMode ? "bg-[#0F1626] border-white/[0.06]" : "bg-white border-black/5"
          }`}>
            <div className={`px-6 py-5 border-b text-center ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
              <div className="w-12 h-12 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-3">
                <CheckCircleIcon className="w-6 h-6" />
              </div>
              <h3 className={`text-base font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Account Set Up!</h3>
              <p className={`text-xs mt-1 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                Credentials for {approvedMerchant.name}
              </p>
            </div>
            <div className="p-6 space-y-3">
              <div className={`p-4 rounded-xl ${darkMode ? "bg-white/[0.03]" : "bg-zinc-50"}`}>
                <div className={`text-[10px] font-semibold uppercase tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Email</div>
                <div className={`text-sm font-mono font-bold ${darkMode ? "text-emerald-400" : "text-emerald-600"}`}>{approvedMerchant.email}</div>
              </div>
              <div className={`p-4 rounded-xl ${darkMode ? "bg-white/[0.03]" : "bg-zinc-50"}`}>
                <div className={`text-[10px] font-semibold uppercase tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Password</div>
                <div className={`text-sm font-mono font-bold ${darkMode ? "text-amber-400" : "text-amber-600"}`}>{approvedMerchant.password}</div>
              </div>
              <p className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                Share these credentials with the merchant. They can change the password after signing in.
              </p>
            </div>
            <div className={`px-6 py-4 border-t flex justify-end ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
              <button
                onClick={() => setApprovedMerchant(null)}
                className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 text-xs font-bold shadow-lg shadow-emerald-500/20 transition-all cursor-pointer"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}
    </DashboardLayout>
  );
}

function DetailField({ label, value, darkMode }) {
  return (
    <div>
      <div className={`text-[10px] font-semibold uppercase tracking-wider mb-0.5 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{label}</div>
      <div className={`text-sm font-medium ${darkMode ? "text-zinc-200" : "text-zinc-800"}`}>{value}</div>
    </div>
  );
}
