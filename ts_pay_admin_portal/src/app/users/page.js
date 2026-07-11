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
    phone: "", ownerName: "", address: "", description: "", cafeId: "",
  });
  const [companies, setCompanies] = useState([]);
  const [companiesLoading, setCompaniesLoading] = useState(false);
  const [toast, setToast] = useState({ message: "", type: "info" });
  const [createdUserCredentials, setCreatedUserCredentials] = useState(null);
  const [editUser, setEditUser] = useState(null);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editRole, setEditRole] = useState("");
  const [editName, setEditName] = useState("");
  const [editEmail, setEditEmail] = useState("");
  const [editOwnerName, setEditOwnerName] = useState("");
  const [editPhone, setEditPhone] = useState("");
  const [editAddress, setEditAddress] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editCafeId, setEditCafeId] = useState("");
  const [editPassword, setEditPassword] = useState("");
  const [showEditPassword, setShowEditPassword] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => { loadUsers(); }, []);

  const loadCompanies = async () => {
    setCompaniesLoading(true);
    try {
      const res = await fetch("/api/profiles?role=ADMIN");
      if (!res.ok) throw new Error("Failed to fetch companies");
      const { profiles } = await res.json();
      console.log("Companies loaded:", profiles);
      setCompanies(profiles || []);
    } catch (err) { console.error("Failed to load companies:", err); }
    finally { setCompaniesLoading(false); }
  };

  const showToast = (msg, type = "success") => {
    setToast({ message: msg, type });
    setTimeout(() => setToast({ message: "", type: "info" }), 4000);
  };

  const handleCopy = (text, typeLabel) => {
    navigator.clipboard.writeText(text);
    showToast(`${typeLabel} copied to clipboard!`, "success");
  };

  const loadUsers = async () => {
    try {
      const res = await fetch("/api/profiles?excludeRole=SUPER_ADMIN");
      if (!res.ok) throw new Error("Failed to fetch users");
      const { profiles } = await res.json();
      setUsers(profiles || []);
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
      const createdRole = newUser.role;
      const creds = {
        name: newUser.fullName,
        email: newUser.email,
        password: newUser.password
      };

      setShowAddModal(false);
      setNewUser({ email: "", password: "", fullName: "", role: "WAITRESS", phone: "", ownerName: "", address: "", description: "", cafeId: "" });
      await loadUsers();
      if (createdRole === "ADMIN") {
        await loadCompanies();
      }
      setCreatedUserCredentials(creds);
    } catch (err) { showToast(err.message, "error"); }
    setCreating(false);
  };



  const handleEditClick = async (user) => {
    await loadCompanies();
    setEditUser(user);
    setEditRole(user.role);
    setEditName(user.full_name || "");
    setEditEmail(user.email || "");
    setEditOwnerName(user.owner_name || "");
    setEditPhone(user.phone || "");
    setEditAddress(user.address || "");
    setEditDescription(user.description || "");
    setEditCafeId(user.cafe_id || "");
    setEditPassword("");
    setShowEditPassword(false);
    setShowEditModal(true);
  };

  const handleSaveEdit = async () => {
    if (!editUser) return;
    setSaving(true);
    try {
      const body = {
        userId: editUser.id,
        role: editRole,
        fullName: editName,
        email: editEmail,
        ownerName: editRole === "ADMIN" ? editOwnerName : null,
        phone: editRole === "ADMIN" ? editPhone : null,
        address: editRole === "ADMIN" ? editAddress : null,
        description: editRole === "ADMIN" ? editDescription : null,
        password: editPassword || undefined,
        cafeId: editRole === "WAITRESS" ? editCafeId : null,
      };
      const res = await fetch("/api/update-role", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const result = await res.json();
      if (!res.ok) { showToast(result.error || "Failed to update user", "error"); setSaving(false); return; }
      await loadUsers();
      setShowEditModal(false);
      setEditUser(null);
      showToast(`User updated successfully`, "success");
    } catch (err) { showToast(err.message, "error"); }
    setSaving(false);
  };

  const handleDeleteUser = async (id, email) => {
    try {
      const res = await fetch("/api/delete-user", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: id }),
      });
      const result = await res.json();
      if (!res.ok) { showToast(result.error || "Failed to delete user", "error"); return; }
      await loadUsers();
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
            onClick={async () => { await loadCompanies(); setShowAddModal(true); }}
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
                autoComplete="off"
                name="search-query"
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

          {/* ── Mobile card view (hidden on md+) ── */}
          <div className="md:hidden">
            {filtered.length === 0 ? (
              <div className={`p-8 text-center text-xs ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>No users found.</div>
            ) : (
              <div className={`divide-y ${darkMode ? "divide-white/[0.04]" : "divide-black/5"}`}>
                {filtered.map((user) => (
                  <div key={user.id} className={`p-4 flex items-start gap-3 transition-colors ${darkMode ? "hover:bg-white/[0.02]" : "hover:bg-zinc-50"}`}>
                    {/* Avatar */}
                    <div className={`w-9 h-9 flex-shrink-0 rounded-xl flex items-center justify-center text-xs font-bold ${
                      user.role === "ADMIN"
                        ? darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"
                        : darkMode ? "bg-amber-500/10 text-amber-400" : "bg-amber-100 text-amber-600"
                    }`}>
                      {(user.full_name || "?")[0]}
                    </div>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className={`font-bold text-sm truncate ${darkMode ? "text-white" : "text-zinc-900"}`}>{user.full_name || "Unnamed"}</span>
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider border flex-shrink-0 ${
                          user.role === "ADMIN"
                            ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
                            : "bg-amber-500/10 text-amber-400 border-amber-500/20"
                        }`}>{user.role}</span>
                      </div>
                      <p className={`text-xs mt-0.5 truncate ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>{user.email}</p>
                      <div className="flex items-center gap-3 mt-1 flex-wrap">
                        {user.company_name && user.company_name !== "—" && (
                          <span className={`text-[11px] font-medium ${darkMode ? "text-zinc-300" : "text-zinc-600"}`}>{user.company_name}</span>
                        )}
                        <span className={`text-[11px] font-mono ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{new Date(user.created_at).toLocaleDateString()}</span>
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex flex-col gap-1.5 flex-shrink-0">
                      <button onClick={() => handleEditClick(user)}
                        className="px-3 py-1.5 rounded-lg font-bold text-[10px] tracking-wide transition-all cursor-pointer bg-emerald-500/10 text-emerald-400 border-emerald-500/20 hover:bg-emerald-500/20 border">
                        Edit
                      </button>
                      <button onClick={() => handleDeleteUser(user.id, user.email)}
                        className="px-3 py-1.5 rounded-lg font-bold text-[10px] tracking-wide transition-all cursor-pointer bg-rose-500/10 text-rose-400 border-rose-500/20 hover:bg-rose-500/20 border">
                        Delete
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* ── Desktop table view (hidden on < md) ── */}
          <div className="hidden md:block overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className={`border-b text-zinc-400 font-bold uppercase tracking-wider ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
                  <th className="p-4 lg:p-5">Name</th>
                  <th className="p-4 lg:p-5 hidden lg:table-cell">Email</th>
                  <th className="p-4 lg:p-5">Company</th>
                  <th className="p-4 lg:p-5">Role</th>
                  <th className="p-4 lg:p-5 hidden xl:table-cell">Joined</th>
                  <th className="p-4 lg:p-5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className={`divide-y font-medium ${darkMode ? "divide-white/[0.04] text-zinc-300" : "divide-black/5 text-zinc-700"}`}>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={6} className={`p-8 text-center text-xs ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>No users found.</td>
                  </tr>
                ) : filtered.map((user) => (
                  <tr key={user.id} className={`transition-colors ${darkMode ? "hover:bg-white/[0.02]" : "hover:bg-zinc-50"}`}>
                    <td className="p-4 lg:p-5">
                      <div className="flex items-center gap-3">
                        <div className={`w-8 h-8 flex-shrink-0 rounded-lg flex items-center justify-center text-xs font-bold ${
                          user.role === "ADMIN"
                            ? darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"
                            : darkMode ? "bg-amber-500/10 text-amber-400" : "bg-amber-100 text-amber-600"
                        }`}>
                          {(user.full_name || "?")[0]}
                        </div>
                        <div className="min-w-0">
                          <span className={`font-bold text-sm block truncate ${darkMode ? "text-white" : "text-zinc-900"}`}>{user.full_name || "Unnamed"}</span>
                          <span className={`text-[11px] lg:hidden truncate block ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{user.email}</span>
                        </div>
                      </div>
                    </td>
                    <td className="p-4 lg:p-5 hidden lg:table-cell max-w-[160px]">
                      <span className="block truncate">{user.email}</span>
                    </td>
                    <td className={`p-4 lg:p-5 max-w-[120px] ${darkMode ? "text-zinc-300" : "text-zinc-600"}`}>
                      <span className="block truncate">{user.company_name || "—"}</span>
                    </td>
                    <td className="p-4 lg:p-5">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider border whitespace-nowrap ${
                        user.role === "ADMIN"
                          ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
                          : "bg-amber-500/10 text-amber-400 border-amber-500/20"
                      }`}>{user.role}</span>
                    </td>
                    <td className={`p-4 lg:p-5 font-mono hidden xl:table-cell ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{new Date(user.created_at).toLocaleDateString()}</td>
                    <td className="p-4 lg:p-5 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <button onClick={() => handleEditClick(user)}
                          className="px-3 py-1.5 rounded-lg font-bold text-[10px] tracking-wide transition-all cursor-pointer bg-emerald-500/10 text-emerald-400 border-emerald-500/20 hover:bg-emerald-500/20 border">
                          Edit
                        </button>
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
                        required minLength={8} />
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

                {newUser.role === "WAITRESS" && (
                  <div>
                    <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Assign to Company</label>
                    {companiesLoading ? (
                      <div className={`text-xs px-4 py-2.5 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Loading companies...</div>
                    ) : companies.length === 0 ? (
                      <div className={`text-xs px-4 py-2.5 rounded-xl border ${darkMode ? "border-amber-500/20 text-amber-400" : "border-amber-500/20 text-amber-600"}`}>
                        No companies available. Create an Admin user first.
                      </div>
                    ) : (
                      <select value={newUser.cafeId} onChange={(e) => setNewUser({ ...newUser, cafeId: e.target.value })}
                        className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`}>
                        <option value="">Select a company...</option>
                        {companies.map((c) => (
                          <option key={c.id} value={c.id}>{c.owner_name || c.full_name}</option>
                        ))}
                      </select>
                    )}
                  </div>
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

        {showEditModal && editUser && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4" onClick={() => setShowEditModal(false)}>
            <div className={`relative w-full max-w-md rounded-2xl overflow-hidden shadow-2xl border transition-all ${
              darkMode ? "bg-[#0F1626] border-white/[0.06]" : "bg-white border-black/5"
            }`} onClick={(e) => e.stopPropagation()}>
              <div className={`px-6 py-4 border-b flex items-center justify-between ${
                darkMode ? "border-white/[0.06]" : "border-black/5"
              }`}>
                <div className="flex items-center gap-3">
                  <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"}`}>
                    <UsersIcon className="w-4 h-4" />
                  </div>
                  <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Edit User</h3>
                </div>
                <button onClick={() => setShowEditModal(false)} className={`text-lg hover:opacity-80 font-bold p-1 cursor-pointer ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>✕</button>
              </div>
              <div className="p-6 space-y-4 overflow-y-auto max-h-[70vh]">
                <div>
                  <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Name</label>
                  <input type="text" value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    autoComplete="off"
                    name="edit-user-name"
                    className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`} />
                </div>
                <div>
                  <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Email</label>
                  <input type="email" value={editEmail}
                    onChange={(e) => setEditEmail(e.target.value)}
                    autoComplete="off"
                    name="edit-user-email"
                    className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`} />
                </div>

                {editRole === "WAITRESS" && (
                  <div>
                    <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Company</label>
                    {companiesLoading ? (
                      <div className={`text-xs px-4 py-2.5 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Loading companies...</div>
                    ) : (
                      <select value={editCafeId} onChange={(e) => setEditCafeId(e.target.value)}
                        className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`}>
                        <option value="">Select a company...</option>
                        {companies.map((c) => (
                          <option key={c.id} value={c.id}>{c.owner_name || c.full_name}</option>
                        ))}
                      </select>
                    )}
                  </div>
                )}

                {editRole === "ADMIN" && (
                  <div className={`border-t pt-4 ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
                    <p className={`text-[10px] font-bold uppercase tracking-wider mb-3 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Company Details</p>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Company</label>
                        <select value={editOwnerName} onChange={(e) => setEditOwnerName(e.target.value)}
                          className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"}`}>
                          <option value="">Select a company...</option>
                          {companies.map((c) => (
                            <option key={c.id} value={c.owner_name || c.full_name}>{c.owner_name || c.full_name}</option>
                          ))}
                        </select>
                      </div>
                      <div>
                        <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Phone Number</label>
                        <input type="text" value={editPhone}
                          onChange={(e) => setEditPhone(e.target.value)}
                          placeholder="e.g. +251 911 223 344"
                          className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"}`} />
                      </div>
                      <div className="col-span-2">
                        <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Address</label>
                        <input type="text" value={editAddress}
                          onChange={(e) => setEditAddress(e.target.value)}
                          placeholder="e.g. Addis Ababa, Ethiopia"
                          className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"}`} />
                      </div>
                      <div className="col-span-2">
                        <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Description</label>
                        <textarea value={editDescription}
                          onChange={(e) => setEditDescription(e.target.value)}
                          placeholder="Brief description about the company"
                          rows={2}
                          className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all resize-none ${darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"}`} />
                      </div>
                    </div>
                  </div>
                )}

                <div className={`border-t pt-4 ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
                  <p className={`text-[10px] font-bold uppercase tracking-wider mb-3 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Change Password</p>
                  <div className="relative">
                    <input type={showEditPassword ? "text" : "password"} value={editPassword}
                      onChange={(e) => setEditPassword(e.target.value)}
                      placeholder="Leave blank to keep current password"
                      minLength={8}
                      autoComplete="new-password"
                      name="edit-user-password"
                      className={`w-full px-4 py-2.5 pr-11 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"}`} />
                    <button type="button" onClick={() => setShowEditPassword(!showEditPassword)}
                      className={`absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-lg transition-colors cursor-pointer ${darkMode ? "text-zinc-500 hover:text-zinc-300" : "text-zinc-400 hover:text-zinc-700"}`} tabIndex={-1}>
                      {showEditPassword ? <EyeOffIcon className="w-4 h-4" /> : <EyeIcon className="w-4 h-4" />}
                    </button>
                  </div>
                </div>
                <div className="flex justify-end gap-3 pt-2">
                  <button type="button" onClick={() => setShowEditModal(false)}
                    className={`px-4 py-2.5 rounded-xl text-xs font-bold cursor-pointer transition-all ${darkMode ? "bg-white/5 text-zinc-300 hover:bg-white/10" : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"}`}>
                    Cancel
                  </button>
                  <button type="button" onClick={handleSaveEdit} disabled={saving}
                    className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 font-bold text-xs shadow-lg shadow-emerald-500/20 hover:from-emerald-400 hover:to-emerald-500 transition-all cursor-pointer disabled:opacity-50">
                    {saving ? "Saving..." : "Save"}
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {createdUserCredentials && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
            <div className={`relative w-full max-w-md rounded-2xl overflow-hidden border shadow-2xl animate-scaleIn ${
              darkMode ? "bg-[#0F1626] border-white/[0.06]" : "bg-white border-black/5"
            }`}>
              <div className={`px-6 py-5 border-b text-center ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
                <div className="w-12 h-12 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-3">
                  <CheckCircleIcon className="w-6 h-6" />
                </div>
                <h3 className={`text-base font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>User Created!</h3>
                <p className={`text-xs mt-1 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                  Credentials for {createdUserCredentials.name}
                </p>
              </div>
              <div className="p-6 space-y-3">
                <div className={`p-4 rounded-xl flex items-center justify-between ${darkMode ? "bg-white/[0.03]" : "bg-zinc-50"}`}>
                  <div>
                    <div className={`text-[10px] font-semibold uppercase tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Email</div>
                    <div className={`text-sm font-mono font-bold ${darkMode ? "text-emerald-400" : "text-emerald-600"}`}>{createdUserCredentials.email}</div>
                  </div>
                  <button
                    onClick={() => handleCopy(createdUserCredentials.email, "Email")}
                    className={`px-3 py-1.5 rounded-lg transition-colors cursor-pointer border font-bold text-[10px] uppercase tracking-wide flex-shrink-0 ${
                      darkMode 
                        ? "bg-white/5 border-white/10 text-zinc-400 hover:text-white hover:bg-white/10" 
                        : "bg-white border-zinc-200 text-zinc-600 hover:text-zinc-950 hover:bg-zinc-50"
                    }`}
                    title="Copy email"
                  >
                    Copy
                  </button>
                </div>
                <div className={`p-4 rounded-xl flex items-center justify-between ${darkMode ? "bg-white/[0.03]" : "bg-zinc-50"}`}>
                  <div>
                    <div className={`text-[10px] font-semibold uppercase tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Password</div>
                    <div className={`text-sm font-mono font-bold ${darkMode ? "text-amber-400" : "text-amber-600"}`}>{createdUserCredentials.password}</div>
                  </div>
                  <button
                    onClick={() => handleCopy(createdUserCredentials.password, "Password")}
                    className={`px-3 py-1.5 rounded-lg transition-colors cursor-pointer border font-bold text-[10px] uppercase tracking-wide flex-shrink-0 ${
                      darkMode 
                        ? "bg-white/5 border-white/10 text-zinc-400 hover:text-white hover:bg-white/10" 
                        : "bg-white border-zinc-200 text-zinc-600 hover:text-zinc-950 hover:bg-zinc-50"
                    }`}
                    title="Copy password"
                  >
                    Copy
                  </button>
                </div>
                <p className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                  Share these credentials with the user. They can change the password after signing in.
                </p>
              </div>
              <div className={`px-6 py-4 border-t flex justify-end ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
                <button
                  onClick={() => setCreatedUserCredentials(null)}
                  className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 text-xs font-bold shadow-lg shadow-emerald-500/20 transition-all cursor-pointer"
                >
                  Done
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
