"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { CheckCircleIcon, XCircleIcon, ShieldIcon } from "@/components/Icons";
import DashboardLayout from "../dashboard-layout";

export default function ApprovalsPage() {
  const [merchants, setMerchants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [darkMode, setDarkMode] = useState(true);
  const [reviewing, setReviewing] = useState(null);
  const [toast, setToast] = useState({ message: "", type: "info" });

  useEffect(() => {
    const stored = localStorage.getItem("adminDarkMode");
    if (stored !== null) setDarkMode(JSON.parse(stored));
    loadMerchants();
  }, []);

  useEffect(() => { localStorage.setItem("adminDarkMode", JSON.stringify(darkMode)); }, [darkMode]);

  const showToast = (message, type = "success") => {
    setToast({ message, type });
    setTimeout(() => setToast({ message: "", type: "info" }), 4000);
  };

  const loadMerchants = async () => {
    try {
      const { data } = await supabase.from("profiles").select("*").eq("role", "ADMIN");
      setMerchants(data || []);
    } catch (err) { console.error("Failed to load merchants:", err); }
    finally { setLoading(false); }
  };

  const handleApprove = async (id) => {
    const { error } = await supabase.from("profiles").update({ role: "ADMIN" }).eq("id", id);
    if (error) { showToast(error.message, "error"); return; }
    setMerchants((prev) => prev.filter((m) => m.id !== id));
    showToast("Merchant approved successfully!", "success");
    setReviewing(null);
  };

  const handleReject = async (id) => {
    const { error } = await supabase.from("profiles").delete().eq("id", id);
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
            Review and manage merchant registration requests
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
            <p className={`text-xs mt-2 ${darkMode ? "text-zinc-500" : "text-zinc-500"}`}>All merchant registrations have been reviewed.</p>
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
                  <div className="space-y-2.5">
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
                          <span className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{m.email}</span>
                        </div>
                      </div>
                    </div>
                    <div className={`grid grid-cols-2 gap-x-6 gap-y-1 text-[11px] ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                      <div><span className="font-semibold text-zinc-400">Role:</span> {m.role}</div>
                      <div><span className="font-semibold text-zinc-400">Joined:</span> {new Date(m.created_at).toLocaleDateString()}</div>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <button
                      onClick={() => handleReject(m.id)}
                      className="px-5 py-2.5 rounded-xl bg-rose-500/10 text-rose-400 border border-rose-500/20 hover:bg-rose-500/20 font-bold text-xs transition-all cursor-pointer"
                    >
                      Reject
                    </button>
                    <button
                      onClick={() => handleApprove(m.id)}
                      className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 hover:from-emerald-400 hover:to-emerald-500 text-xs font-bold shadow-lg shadow-emerald-500/20 transition-all cursor-pointer"
                    >
                      Approve
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
