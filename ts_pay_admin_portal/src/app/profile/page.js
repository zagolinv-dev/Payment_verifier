"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { CheckCircleIcon, XCircleIcon, UserIcon, EyeIcon, EyeOffIcon } from "@/components/Icons";
import DashboardLayout from "../dashboard-layout";

export default function ProfilePage() {
  const router = useRouter();
  const [darkMode, setDarkMode] = useState(true);
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState({ message: "", type: "info" });
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [newEmail, setNewEmail] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);
  const [savingEmail, setSavingEmail] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem("adminDarkMode");
    if (stored !== null) setDarkMode(JSON.parse(stored));
    loadProfile();
  }, []);

  useEffect(() => { localStorage.setItem("adminDarkMode", JSON.stringify(darkMode)); }, [darkMode]);

  const showToast = (msg, type = "success") => {
    setToast({ message: msg, type });
    setTimeout(() => setToast({ message: "", type: "info" }), 4000);
  };

  const loadProfile = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) { router.push("/"); return; }
      setUser(session.user);
      setNewEmail(session.user.email || "");
      const { data: p } = await supabase.from("profiles").select("*").eq("id", session.user.id).single();
      setProfile(p);
    } catch (err) { console.error("Failed to load profile:", err); }
    finally { setLoading(false); }
  };

  const handleChangePassword = async (e) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) { showToast("Passwords do not match.", "error"); return; }
    if (newPassword.length < 6) { showToast("Password must be at least 6 characters.", "error"); return; }
    setSavingPassword(true);
    try {
      const { error } = await supabase.auth.updateUser({ password: newPassword });
      if (error) throw error;
      showToast("Password updated successfully!", "success");
      setNewPassword(""); setConfirmPassword("");
    } catch (err) { showToast(err.message, "error"); }
    finally { setSavingPassword(false); }
  };

  const handleChangeEmail = async (e) => {
    e.preventDefault();
    setSavingEmail(true);
    try {
      const { error } = await supabase.auth.updateUser({ email: newEmail });
      if (error) throw error;
      showToast("Confirmation email sent. Please check your inbox.", "success");
    } catch (err) { showToast(err.message, "error"); }
    finally { setSavingEmail(false); }
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
            <span className="text-xs font-medium text-zinc-500">Loading profile...</span>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout darkMode={darkMode} setDarkMode={setDarkMode}>
      <div className="space-y-6 max-w-2xl animate-scaleIn">
        <div>
          <h1 className={`text-xl sm:text-2xl font-bold tracking-tight ${darkMode ? "text-white" : "text-zinc-900"}`}>
            My Profile
          </h1>
          <p className={`text-xs mt-1 ${darkMode ? "text-zinc-500" : "text-zinc-500"}`}>
            Manage your account credentials and security settings
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

        <div className={`relative overflow-hidden rounded-2xl p-6 sm:p-8 border transition-all ${
          darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
        }`}>
          <div className={`absolute top-0 right-0 w-48 h-48 rounded-full blur-3xl pointer-events-none ${darkMode ? "bg-emerald-500/5" : "bg-emerald-500/3"}`} />
            <div className={`relative flex items-center gap-4 mb-6 pb-5 border-b ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
            <div className={`w-14 h-14 rounded-xl flex items-center justify-center text-lg font-bold ${
              darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"
            }`}>
              {(profile?.full_name || "A")[0]}
            </div>
            <div>
              <h3 className={`text-base font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>{profile?.full_name || "Super Admin"}</h3>
              <div className="flex items-center gap-2 mt-1">
                <span className="bg-emerald-500/10 text-emerald-400 px-2 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider border border-emerald-500/20">
                  {profile?.role || "ADMIN"}
                </span>
                <span className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{user?.email}</span>
              </div>
            </div>
          </div>
          <div className="relative grid grid-cols-2 gap-4 text-sm">
            <div>
              <div className={`text-[10px] uppercase font-bold tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Email</div>
              <div className={`font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>{user?.email}</div>
            </div>
            <div>
              <div className={`text-[10px] uppercase font-bold tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Full Name</div>
              <div className={`font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>{profile?.full_name || "Super Admin"}</div>
            </div>
            <div>
              <div className={`text-[10px] uppercase font-bold tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Role</div>
              <div className="font-bold">
                <span className="bg-emerald-500/10 text-emerald-400 px-2.5 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider border border-emerald-500/20">
                  {profile?.role || "ADMIN"}
                </span>
              </div>
            </div>
            <div>
              <div className={`text-[10px] uppercase font-bold tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Joined</div>
              <div className={`font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>
                {profile?.created_at ? new Date(profile.created_at).toLocaleDateString() : "N/A"}
              </div>
            </div>
          </div>
        </div>

        <div className={`relative overflow-hidden rounded-2xl p-6 sm:p-8 border transition-all ${
          darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
        }`}>
          <div className={`relative flex items-center gap-3 mb-6 pb-5 border-b ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
            <div className={`w-9 h-9 rounded-lg flex items-center justify-center ${
              darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"
            }`}>
              <UserIcon className="w-5 h-5" />
            </div>
            <div>
              <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Change Email</h3>
              <p className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                Update your account email address
              </p>
            </div>
          </div>
          <form onSubmit={handleChangeEmail} className="relative space-y-4">
            <div>
              <label className={`text-xs font-bold block mb-2 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>New Email Address</label>
              <input
                type="email" value={newEmail}
                onChange={(e) => setNewEmail(e.target.value)}
                className={`w-full px-4 py-3 rounded-xl border text-sm outline-none transition-all ${
                  darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"
                }`}
                required
              />
            </div>
            <button
              type="submit"
              disabled={savingEmail}
              className="w-full py-3 bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 font-bold rounded-xl shadow-lg shadow-emerald-500/20 hover:from-emerald-400 hover:to-emerald-500 disabled:opacity-50 transition-all cursor-pointer text-xs"
            >
              {savingEmail ? (
                <span className="flex items-center justify-center gap-2">
                  <span className="w-4 h-4 border-2 border-zinc-950/30 border-t-zinc-950 rounded-full animate-spin" />
                  Sending...
                </span>
              ) : "Update Email"}
            </button>
          </form>
        </div>

        <div className={`relative overflow-hidden rounded-2xl p-6 sm:p-8 border transition-all ${
          darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
        }`}>
          <div className={`relative flex items-center gap-3 mb-6 pb-5 border-b ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
            <div className={`w-9 h-9 rounded-lg flex items-center justify-center ${
              darkMode ? "bg-amber-500/10 text-amber-400" : "bg-amber-100 text-amber-600"
            }`}>
              <LockIcon className="w-5 h-5" />
            </div>
            <div>
              <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Change Password</h3>
              <p className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                Set a new password for your account
              </p>
            </div>
          </div>
          <form onSubmit={handleChangePassword} className="relative space-y-4">
            <div>
              <label className={`text-xs font-bold block mb-2 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>New Password</label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"} value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className={`w-full px-4 py-3 pr-11 rounded-xl border text-sm outline-none transition-all ${
                    darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"
                  }`}
                  placeholder="Enter new password"
                  required minLength={6}
                />
                <button
                  type="button" onClick={() => setShowPassword(!showPassword)}
                  className={`absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-lg transition-colors cursor-pointer ${
                    darkMode ? "text-zinc-500 hover:text-zinc-300" : "text-zinc-400 hover:text-zinc-700"
                  }`} tabIndex={-1}
                >
                  {showPassword ? <EyeOffIcon className="w-4 h-4" /> : <EyeIcon className="w-4 h-4" />}
                </button>
              </div>
            </div>
            <div>
              <label className={`text-xs font-bold block mb-2 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>Confirm Password</label>
              <div className="relative">
                <input
                  type={showConfirm ? "text" : "password"} value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className={`w-full px-4 py-3 pr-11 rounded-xl border text-sm outline-none transition-all ${
                    darkMode ? "bg-[#080E1A] border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50" : "bg-zinc-50 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50"
                  }`}
                  placeholder="Confirm new password"
                  required minLength={6}
                />
                <button
                  type="button" onClick={() => setShowConfirm(!showConfirm)}
                  className={`absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-lg transition-colors cursor-pointer ${
                    darkMode ? "text-zinc-500 hover:text-zinc-300" : "text-zinc-400 hover:text-zinc-700"
                  }`} tabIndex={-1}
                >
                  {showConfirm ? <EyeOffIcon className="w-4 h-4" /> : <EyeIcon className="w-4 h-4" />}
                </button>
              </div>
            </div>
            <button
              type="submit"
              disabled={savingPassword}
              className="w-full py-3 bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 font-bold rounded-xl shadow-lg shadow-emerald-500/20 hover:from-emerald-400 hover:to-emerald-500 disabled:opacity-50 transition-all cursor-pointer text-xs"
            >
              {savingPassword ? (
                <span className="flex items-center justify-center gap-2">
                  <span className="w-4 h-4 border-2 border-zinc-950/30 border-t-zinc-950 rounded-full animate-spin" />
                  Updating...
                </span>
              ) : "Update Password"}
            </button>
          </form>
        </div>
      </div>
    </DashboardLayout>
  );
}

function LockIcon({ className }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
      <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
    </svg>
  );
}
