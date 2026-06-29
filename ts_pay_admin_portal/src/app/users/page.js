"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { SearchIcon, CheckCircleIcon, XCircleIcon, UsersIcon, EyeIcon, EyeOffIcon } from "@/components/Icons";
import DashboardLayout from "../dashboard-layout";

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [darkMode, setDarkMode] = useState(() => typeof window !== "undefined" ? JSON.parse(localStorage.getItem("adminDarkMode") ?? "false") : false);
  const [searchQuery, setSearchQuery] = useState("");
  const [showAddModal, setShowAddModal] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [creating, setCreating] = useState(false);
  const [newUser, setNewUser] = useState({
    email: "", password: "", fullName: "", role: "WAITRESS",
    phone: "", ownerName: "", address: "", description: "",
  });
  const [toast, setToast] = useState({ message: "", type: "info" });

  useEffect(() => { loadUsers(); }, []);

  const showToast = (msg, type = "success") => {
    setToast({ message: msg, type });
    setTimeout(() => setToast({ message: "", type: "info" }), 4000);
  };

  const loadUsers = async () => {
    try {
      const { data, error } = await supabase.from("profiles").select("*").order("created_at", { ascending: false });
      if (error) throw error;
      setUsers(data || []);
    } catch (err) { console.error("Failed to load users:", err); }
    finally { setLoading(false); }
  };

  const handleAddUser = async (e) => {
    e.preventDefault();
    setCreating(true);
    try {
      const res = await fetch("/api/create-user", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(newUser),
      });
      const result = await res.json();
      if (!res.ok) { showToast(result.error || "Failed to create user", "error"); setCreating(false); return; }
      showToast(`User ${newUser.email} created successfully!`, "success");
      setShowAddModal(false);
      setNewUser({ email: "", password: "", fullName: "", role: "WAITRESS", phone: "", ownerName: "", address: "", description: "" });
      await loadUsers();
    } catch (err) { showToast(err.message, "error"); }
    setCreating(false);
  };

  const handleUpdateRole = async (id, newRole) => {
    try {
      const { error } = await supabase.from("profiles").update({ role: newRole }).eq("id", id);
      if (error) throw error;
      setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, role: newRole } : u)));
      showToast(`User role updated to ${newRole}`, "success");
    } catch (err) { showToast(err.message, "error"); }
  };

  const handleDeleteUser = async (id, email) => {
    try {
      const { error } = await supabase.from("profiles").delete().eq("id", id);
      if (error) throw error;
      setUsers((prev) => prev.filter((u) => u.id !== id));
      showToast(`User ${email} deleted.`, "success");
    } catch (err) { showToast(err.message, "error"); }
  };

  const filtered = users.filter(
    (u) => (u.full_name || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
           (u.email || "").toLowerCase().includes(searchQuery.toLowerCase())
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
            <span className="text-xs font-medium text-zinc-500">Loading users...</span>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout darkMode={darkMode} setDarkMode={setDarkMode}>
      <div className="space-y-6 animate-scaleIn">
        <div className="flex items-center justify-between">
          <div>
            <h1 className={`text-xl sm:text-2xl font-bold tracking-tight ${darkMode ? "text-white" : "text-zinc-900"}`}>Users</h1>
            <p className={`text-xs mt-1 ${darkMode ? "text-zinc-500" : "text-zinc-500"}`}>Manage all platform users and their roles</p>
          </div>
          <button
            onClick={() => setShowAddModal(true)}
            className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 font-bold text-xs shadow-lg shadow-emerald-500/20 hover:from-emerald-400 hover:to-emerald-500 transition-all cursor-pointer"
          >
            + Add User
          </button>
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
                type="text" value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search users..."
                className={`w-full text-xs pl-9 pr-4 py-2.5 rounded-xl border outline-none transition-all ${
                  darkMode
                    ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                    : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                }`}
              />
            </div>
            <div className={`text-xs font-semibold flex items-center gap-2 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
              <UsersIcon className="w-4 h-4" />
              Showing <span className="text-emerald-500 font-extrabold">{filtered.length}</span> users
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
                  <th className="p-4 sm:p-5">Name</th>
                  <th className="p-4 sm:p-5">Email</th>
                  <th className="p-4 sm:p-5">Role</th>
                  <th className="p-4 sm:p-5">Joined</th>
                  <th className="p-4 sm:p-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className={`divide-y font-medium ${darkMode ? "divide-white/[0.04] text-zinc-300" : "divide-black/5 text-zinc-700"}`}>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={5} className={`p-8 text-center text-xs ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>No users found.</td>
                  </tr>
                ) : filtered.map((user) => (
                  <tr key={user.id} className={`transition-colors ${darkMode ? "hover:bg-white/[0.02]" : "hover:bg-zinc-50"}`}>
                    <td className="p-4 sm:p-5">
                      <div className="flex items-center gap-3">
                        <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-xs font-bold ${
                          user.role === "ADMIN"
                            ? darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"
                            : darkMode ? "bg-amber-500/10 text-amber-400" : "bg-amber-100 text-amber-600"
                        }`}>
                          {(user.full_name || "?")[0]}
                        </div>
                        <span className={`font-bold text-sm ${darkMode ? "text-white" : "text-zinc-900"}`}>{user.full_name || "Unnamed"}</span>
                      </div>
                    </td>
                    <td className="p-4 sm:p-5">{user.email}</td>
                    <td className="p-4 sm:p-5">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider border ${
                        user.role === "ADMIN"
                          ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
                          : "bg-amber-500/10 text-amber-400 border-amber-500/20"
                      }`}>{user.role}</span>
                    </td>
                    <td className={`p-4 sm:p-5 font-mono ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{new Date(user.created_at).toLocaleDateString()}</td>
                    <td className="p-4 sm:p-5 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <select value={user.role} onChange={(e) => handleUpdateRole(user.id, e.target.value)}
                          className={`text-[10px] px-2 py-1.5 rounded-lg border font-bold outline-none cursor-pointer transition-all ${
                            darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"
                          }`}>
                          <option value="WAITRESS">WAITRESS</option>
                          <option value="ADMIN">ADMIN</option>
                        </select>
                        <button onClick={() => handleDeleteUser(user.id, user.email)}
                          className="px-3 py-1.5 rounded-lg font-bold text-[10px] tracking-wide transition-all cursor-pointer bg-rose-500/10 text-rose-400 border-rose-500/20 hover:bg-rose-500/20 border">
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

        {showAddModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 overflow-y-auto" onClick={() => setShowAddModal(false)}>
            <div className={`relative w-full max-w-lg rounded-2xl overflow-hidden shadow-2xl border transition-all my-8 ${
              darkMode ? "bg-[#0F1626] border-white/[0.06]" : "bg-white border-black/5"
            }`} onClick={(e) => e.stopPropagation()}>
              <div className={`px-6 py-4 border-b flex items-center justify-between ${
                darkMode ? "border-white/[0.06]" : "border-black/5"
              }`}>
                <div className="flex items-center gap-3">
                  <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"}`}>
                    <UsersIcon className="w-4 h-4" />
                  </div>
                  <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Add New User</h3>
                </div>
                <button onClick={() => setShowAddModal(false)} className={`text-lg hover:opacity-80 font-bold p-1 cursor-pointer ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>✕</button>
              </div>
              <form onSubmit={handleAddUser} className="p-6 space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div className="col-span-2">
                    <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Full Name</label>
                    <input type="text" value={newUser.fullName}
                      onChange={(e) => setNewUser({ ...newUser, fullName: e.target.value })}
                      className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`}
                      required />
                  </div>
                  <div>
                    <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Email</label>
                    <input type="email" value={newUser.email}
                      onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
                      className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`}
                      required />
                  </div>
                  <div>
                    <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Password</label>
                    <div className="relative">
                      <input type={showPassword ? "text" : "password"} value={newUser.password}
                        onChange={(e) => setNewUser({ ...newUser, password: e.target.value })}
                        className={`w-full px-4 py-2.5 pr-11 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`}
                        required minLength={6} />
                      <button type="button" onClick={() => setShowPassword(!showPassword)}
                        className={`absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-lg transition-colors cursor-pointer ${darkMode ? "text-zinc-500 hover:text-zinc-300" : "text-zinc-400 hover:text-zinc-700"}`} tabIndex={-1}>
                        {showPassword ? <EyeOffIcon className="w-4 h-4" /> : <EyeIcon className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>
                </div>

                <div>
                  <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Role</label>
                  <select value={newUser.role} onChange={(e) => setNewUser({ ...newUser, role: e.target.value })}
                    className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`}>
                    <option value="WAITRESS">Waitress</option>
                    <option value="ADMIN">Admin (Manager)</option>
                  </select>
                </div>

                {newUser.role === "ADMIN" && (
                  <>
                    <div className={`border-t pt-4 ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
                      <p className={`text-[10px] font-bold uppercase tracking-wider mb-3 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Company Details</p>
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Company Name</label>
                          <input type="text" value={newUser.ownerName}
                            onChange={(e) => setNewUser({ ...newUser, ownerName: e.target.value })}
                            placeholder="Same as Full Name if sole owner"
                            className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"}`} />
                        </div>
                        <div>
                          <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Phone Number</label>
                          <input type="text" value={newUser.phone}
                            onChange={(e) => setNewUser({ ...newUser, phone: e.target.value })}
                            placeholder="e.g. +251 911 223 344"
                            className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"}`} />
                        </div>
                        <div className="col-span-2">
                          <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Address</label>
                          <input type="text" value={newUser.address}
                            onChange={(e) => setNewUser({ ...newUser, address: e.target.value })}
                            placeholder="e.g. Addis Ababa, Ethiopia"
                            className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"}`} />
                        </div>
                        <div className="col-span-2">
                          <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Description</label>
                          <textarea value={newUser.description}
                            onChange={(e) => setNewUser({ ...newUser, description: e.target.value })}
                            placeholder="Brief description about the company"
                            rows={2}
                            className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all resize-none ${darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"}`} />
                        </div>
                      </div>
                    </div>
                  </>
                )}

                <div className="flex justify-end gap-3 pt-2">
                  <button type="button" onClick={() => setShowAddModal(false)}
                    className={`px-4 py-2.5 rounded-xl text-xs font-bold cursor-pointer transition-all ${darkMode ? "bg-white/5 text-zinc-300 hover:bg-white/10" : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"}`}>
                    Cancel
                  </button>
                  <button type="submit" disabled={creating}
                    className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 font-bold text-xs shadow-lg shadow-emerald-500/20 hover:from-emerald-400 hover:to-emerald-500 transition-all cursor-pointer disabled:opacity-50">
                    {creating ? "Creating..." : "Create User"}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
