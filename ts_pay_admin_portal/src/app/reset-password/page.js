"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { EyeIcon, EyeOffIcon, CheckCircleIcon, XCircleIcon } from "@/components/Icons";

export default function ResetPasswordPage() {
  const router = useRouter();
  const [session, setSession] = useState(null);
  const [checking, setChecking] = useState(true);
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);
  const [darkMode, setDarkMode] = useState(
    () => typeof window !== "undefined"
      ? JSON.parse(localStorage.getItem("adminDarkMode") ?? "false")
      : false
  );

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session) {
        router.push("/");
        return;
      }
      setSession(session);
      setChecking(false);
    });
  }, [router]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");

    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      return;
    }
    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);
    const { error: updateError } = await supabase.auth.updateUser({ password });

    if (updateError) {
      setError(updateError.message);
      setLoading(false);
      return;
    }

    setSuccess(true);
    setTimeout(() => router.push("/dashboard"), 2000);
  };

  if (checking) {
    return (
      <div className="min-h-screen bg-zinc-50 flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <img src="/logo.png" alt="T's Verify" className="w-14 h-14 object-contain animate-pulse" />
          <div className="flex gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "0ms" }} />
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "150ms" }} />
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "300ms" }} />
          </div>
        </div>
      </div>
    );
  }

  if (success) {
    return (
      <div className={`min-h-screen flex items-center justify-center font-sans p-4 ${
        darkMode ? "bg-[#080E1A] text-zinc-100" : "bg-zinc-50 text-zinc-900"
      }`}>
        <div className={`relative rounded-2xl p-8 border max-w-md w-full text-center ${
          darkMode ? "bg-[#0F1626]/80 border-white/[0.06]" : "bg-white/80 border-black/5 shadow-sm"
        }`}>
          <CheckCircleIcon className="w-12 h-12 text-emerald-400 mx-auto mb-4" />
          <h2 className="text-lg font-bold mb-2">Password Updated</h2>
          <p className="text-sm text-zinc-400">Redirecting to dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className={`min-h-screen flex items-center justify-center font-sans p-4 transition-colors duration-500 ${
      darkMode ? "bg-[#080E1A] text-zinc-100" : "bg-zinc-50 text-zinc-900"
    }`}>
      <div className={`relative rounded-2xl p-8 border max-w-md w-full ${
        darkMode
          ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]"
          : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
      }`}>
        <div className="flex flex-col items-center mb-6">
          <img src="/logo.png" alt="T's Verify" className="w-12 h-12 object-contain mb-3" />
          <h2 className="text-lg font-bold tracking-tight">Reset Your Password</h2>
          <p className={`text-xs mt-1 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
            Enter your new password below
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className={`block text-[11px] font-semibold uppercase tracking-wider mb-2 ${
              darkMode ? "text-zinc-400" : "text-zinc-600"
            }`}>New Password</label>
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className={`w-full px-4 py-3 pr-11 rounded-xl border text-sm outline-none transition-all ${
                  darkMode
                    ? "bg-white/5 border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                    : "bg-black/5 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                }`}
                placeholder="Min. 6 characters"
                required
                minLength={6}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className={`absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-lg transition-colors cursor-pointer ${
                  darkMode ? "text-zinc-500 hover:text-zinc-300" : "text-zinc-400 hover:text-zinc-700"
                }`}
                tabIndex={-1}
              >
                {showPassword ? <EyeOffIcon className="w-4 h-4" /> : <EyeIcon className="w-4 h-4" />}
              </button>
            </div>
          </div>

          <div>
            <label className={`block text-[11px] font-semibold uppercase tracking-wider mb-2 ${
              darkMode ? "text-zinc-400" : "text-zinc-600"
            }`}>Confirm Password</label>
            <div className="relative">
              <input
                type={showConfirm ? "text" : "password"}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className={`w-full px-4 py-3 pr-11 rounded-xl border text-sm outline-none transition-all ${
                  darkMode
                    ? "bg-white/5 border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                    : "bg-black/5 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                }`}
                placeholder="Repeat new password"
                required
                minLength={6}
              />
              <button
                type="button"
                onClick={() => setShowConfirm(!showConfirm)}
                className={`absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-lg transition-colors cursor-pointer ${
                  darkMode ? "text-zinc-500 hover:text-zinc-300" : "text-zinc-400 hover:text-zinc-700"
                }`}
                tabIndex={-1}
              >
                {showConfirm ? <EyeOffIcon className="w-4 h-4" /> : <EyeIcon className="w-4 h-4" />}
              </button>
            </div>
          </div>

          {error && (
            <div className="flex items-center gap-2 p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs font-medium">
              <XCircleIcon className="w-4 h-4 flex-shrink-0" />
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="relative w-full py-3.5 mt-2 font-bold rounded-xl text-sm overflow-hidden group transition-all duration-200 disabled:opacity-50 cursor-pointer"
          >
            <div className="absolute inset-0 bg-gradient-to-r from-emerald-500 via-emerald-400 to-emerald-500 bg-[length:200%_100%] group-hover:bg-[length:150%_100%] transition-all duration-700" />
            <div className="absolute inset-0 bg-gradient-to-r from-emerald-600/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
            <span className="relative text-zinc-950">
              {loading ? (
                <span className="flex items-center justify-center gap-2">
                  <span className="w-4 h-4 border-2 border-zinc-950/30 border-t-zinc-950 rounded-full animate-spin" />
                  Updating...
                </span>
              ) : "Reset Password"}
            </span>
          </button>
        </form>
      </div>
    </div>
  );
}
