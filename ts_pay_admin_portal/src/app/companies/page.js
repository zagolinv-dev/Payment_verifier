"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { SearchIcon, CheckCircleIcon, XCircleIcon, BuildingIcon } from "@/components/Icons";
import DashboardLayout from "../dashboard-layout";

export default function CompaniesPage() {
  const [companies, setCompanies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [darkMode, setDarkMode] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [toast, setToast] = useState({ message: "", type: "info" });

  useEffect(() => {
    const stored = localStorage.getItem("adminDarkMode");
    if (stored !== null) setDarkMode(JSON.parse(stored));
    loadData();
  }, []);

  useEffect(() => { localStorage.setItem("adminDarkMode", JSON.stringify(darkMode)); }, [darkMode]);

  const showToast = (msg, type = "success") => {
    setToast({ message: msg, type });
    setTimeout(() => setToast({ message: "", type: "info" }), 4000);
  };

  const loadData = async () => {
    try {
      const { data: merchants } = await supabase.from("profiles").select("*").eq("role", "ADMIN");
      const { data: txData } = await supabase.from("transactions").select("verified_by, amount");
      const totalMap = {};
      (txData || []).forEach((t) => {
        if (t.verified_by) totalMap[t.verified_by] = (totalMap[t.verified_by] || 0) + (Number(t.amount) || 0);
      });
      setCompanies((merchants || []).map((m) => ({ ...m, total: totalMap[m.id] || 0, status: "ACTIVE" })));
    } catch (err) { console.error("Failed to load companies:", err); }
    finally { setLoading(false); }
  };

  const handleToggleStatus = async (id, currentStatus) => {
    const newStatus = currentStatus === "ACTIVE" ? "SUSPENDED" : "ACTIVE";
    const newRole = newStatus === "ACTIVE" ? "ADMIN" : "WAITRESS";
    const { error } = await supabase.from("profiles").update({ role: newRole }).eq("id", id);
    if (error) { showToast(error.message, "error"); return; }
    setCompanies((prev) => prev.map((c) => (c.id === id ? { ...c, status: newStatus, role: newRole } : c)));
    showToast(newStatus === "ACTIVE" ? "Company re-activated." : "Company suspended.", newStatus === "ACTIVE" ? "success" : "warning");
  };

  const handleDelete = async (id, name) => {
    const { error } = await supabase.from("profiles").delete().eq("id", id);
    if (error) { showToast(error.message, "error"); return; }
    setCompanies((prev) => prev.filter((c) => c.id !== id));
    showToast(`${name} removed from platform.`, "error");
  };

  const filtered = companies.filter(
    (c) => (c.full_name || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
           (c.email || "").toLowerCase().includes(searchQuery.toLowerCase())
  );

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
            <span className="text-xs font-medium text-zinc-500">Loading companies...</span>
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
            Companies
          </h1>
          <p className={`text-xs mt-1 ${darkMode ? "text-zinc-500" : "text-zinc-500"}`}>
            Manage registered merchant companies
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

        <div className={`relative overflow-hidden rounded-2xl p-4 sm:p-5 border transition-all ${
          darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
        }`}>
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="relative w-full md:max-w-xs">
              <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search companies..."
                className={`w-full text-xs pl-9 pr-4 py-2.5 rounded-xl border outline-none transition-all ${
                  darkMode
                    ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                    : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                }`}
              />
            </div>
            <div className={`text-xs font-semibold flex items-center gap-2 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
              <BuildingIcon className="w-4 h-4" />
              Showing <span className="text-emerald-500 font-extrabold">{filtered.length}</span> companies
            </div>
          </div>
        </div>

        <div className={`relative overflow-hidden rounded-2xl border transition-all ${
          darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
        }`}>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className={`border-b text-zinc-400 font-bold uppercase tracking-wider ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
                  <th className="p-4 sm:p-5">Company</th>
                  <th className="p-4 sm:p-5">Email</th>
                  <th className="p-4 sm:p-5">Total</th>
                  <th className="p-4 sm:p-5">Status</th>
                  <th className="p-4 sm:p-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className={`divide-y font-medium ${darkMode ? "divide-white/[0.04] text-zinc-300" : "divide-black/5 text-zinc-700"}`}>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={5} className={`p-8 text-center text-xs ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                      No companies found matching your search.
                    </td>
                  </tr>
                ) : filtered.map((company) => (
                  <tr key={company.id} className={`transition-colors ${darkMode ? "hover:bg-white/[0.02]" : "hover:bg-zinc-50"}`}>
                    <td className="p-4 sm:p-5">
                      <div className="flex items-center gap-3">
                        <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-xs font-bold ${
                          darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"
                        }`}>
                          {(company.full_name || "?")[0]}
                        </div>
                        <span className={`font-bold text-sm ${darkMode ? "text-white" : "text-zinc-900"}`}>
                          {company.full_name || "Unnamed"}
                        </span>
                      </div>
                    </td>
                    <td className="p-4 sm:p-5">{company.email}</td>
                    <td className={`p-4 sm:p-5 font-mono font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>
                      {company.total.toLocaleString()} ETB
                    </td>
                    <td className="p-4 sm:p-5">
                      <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider border ${
                        company.status === "ACTIVE"
                          ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
                          : "bg-rose-500/10 text-rose-400 border-rose-500/20"
                      }`}>
                        {company.status === "ACTIVE" ? "Active" : "Suspended"}
                      </span>
                    </td>
                    <td className="p-4 sm:p-5 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => handleToggleStatus(company.id, company.status)}
                          className={`px-3 py-1.5 rounded-lg font-bold text-[10px] tracking-wide transition-all cursor-pointer border ${
                            company.status === "ACTIVE"
                              ? "bg-rose-500/10 text-rose-400 border-rose-500/20 hover:bg-rose-500/20"
                              : "bg-emerald-500/10 text-emerald-400 border-emerald-500/20 hover:bg-emerald-500/20"
                          }`}
                        >
                          {company.status === "ACTIVE" ? "Suspend" : "Activate"}
                        </button>
                        <button
                          onClick={() => handleDelete(company.id, company.full_name || "Company")}
                          className="px-3 py-1.5 rounded-lg font-bold text-[10px] tracking-wide transition-all cursor-pointer bg-rose-500/10 text-rose-400 border-rose-500/20 hover:bg-rose-500/20 border"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}
