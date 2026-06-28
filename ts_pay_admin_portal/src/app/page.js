"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { SunIcon, MoonIcon, EyeIcon, EyeOffIcon } from "@/components/Icons";

function SplashScreen({ darkMode }) {
  const [show, setShow] = useState(true);

  useEffect(() => {
    const t = setTimeout(() => setShow(false), 2000);
    return () => clearTimeout(t);
  }, []);

  if (!show) return null;

  return (
    <div className={`fixed inset-0 z-[100] flex flex-col items-center justify-center transition-opacity duration-700 ${
      darkMode ? "bg-[#080E1A]" : "bg-zinc-50"
    }`}>
      <div className="relative animate-float">
        <div className={`absolute inset-0 rounded-full blur-3xl ${darkMode ? "bg-emerald-500/10" : "bg-emerald-500/5"}`} />
        <img
          src="/logo.png"
          alt="T's Verify"
          className="relative w-24 h-24 md:w-32 md:h-32 object-contain"
        />
      </div>
      <div className="mt-8 flex flex-col items-center gap-1">
        <div className="flex gap-1.5">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "0ms" }} />
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "150ms" }} />
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "300ms" }} />
        </div>
        <p className={`mt-3 text-xs font-bold tracking-[0.2em] uppercase ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
          Loading Portal
        </p>
      </div>
    </div>
  );
}

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("admin@tspay.com");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [darkMode, setDarkMode] = useState(true);
  const [splashDone, setSplashDone] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setSplashDone(true), 2000);
    return () => clearTimeout(t);
  }, []);

  useEffect(() => {
    const stored = localStorage.getItem("adminDarkMode");
    if (stored !== null) setDarkMode(JSON.parse(stored));
  }, []);

  useEffect(() => {
    localStorage.setItem("adminDarkMode", JSON.stringify(darkMode));
  }, [darkMode]);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    if (!email.includes("@")) {
      setError("Please enter a valid email address.");
      setLoading(false);
      return;
    }
    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      setLoading(false);
      return;
    }

    const { error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (authError) {
      setError(authError.message);
      setLoading(false);
      return;
    }

    router.push("/dashboard");
  };

  return (
    <>
      {!splashDone && <SplashScreen darkMode={darkMode} />}
      <div className={`relative min-h-screen flex items-center justify-center font-sans overflow-hidden p-4 transition-colors duration-500 ${
        darkMode ? "bg-[#080E1A] text-zinc-100" : "bg-zinc-50 text-zinc-900"
      }`}>
        {/* Background decoration */}
        <div className={`absolute inset-0 overflow-hidden pointer-events-none`}>
          <div className={`absolute -top-40 -right-40 w-96 h-96 rounded-full blur-3xl opacity-20 ${darkMode ? "bg-emerald-500" : "bg-emerald-300"}`} />
          <div className={`absolute -bottom-40 -left-40 w-80 h-80 rounded-full blur-3xl opacity-10 ${darkMode ? "bg-emerald-400" : "bg-emerald-500"}`} />
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full bg-gradient-to-br from-emerald-500/3 to-transparent blur-3xl" />
        </div>

        <div className="absolute top-4 right-4 z-10">
          <button
            onClick={() => setDarkMode(!darkMode)}
            className={`p-2.5 rounded-xl border transition-all cursor-pointer backdrop-blur-sm ${
              darkMode
                ? "bg-white/5 border-white/10 text-amber-400 hover:bg-white/10 hover:text-amber-300"
                : "bg-black/5 border-black/10 text-zinc-700 hover:bg-black/10 hover:text-zinc-950"
            }`}
            aria-label="Toggle theme"
          >
            {darkMode ? <SunIcon className="w-4 h-4 sm:w-5 sm:h-5" /> : <MoonIcon className="w-4 h-4 sm:w-5 sm:h-5" />}
          </button>
        </div>

        <div className="relative w-full max-w-sm sm:max-w-md">
          <div className={`relative rounded-3xl p-8 sm:p-10 shadow-2xl transition-all duration-500 ${
            darkMode
              ? "bg-[#0F1626]/80 backdrop-blur-xl border border-white/[0.06] shadow-black/60"
              : "bg-white/80 backdrop-blur-xl border border-black/5 shadow-xl shadow-black/5"
          }`}>
            {/* Inner glow */}
            <div className={`absolute inset-0 rounded-3xl pointer-events-none ${
              darkMode ? "bg-gradient-to-b from-emerald-500/[0.03] to-transparent" : "bg-gradient-to-b from-emerald-500/[0.02] to-transparent"
            }`} />

            <div className="relative flex flex-col items-center mb-8">
              <div className="relative mb-4">
                <div className={`absolute inset-0 rounded-2xl blur-xl ${darkMode ? "bg-emerald-500/15" : "bg-emerald-500/10"}`} />
                <img
                  src="/logo.png"
                  alt="T's Verify"
                  className="relative w-16 h-16 sm:w-20 sm:h-20 object-contain"
                />
              </div>
              <h2 className="text-xl sm:text-2xl font-bold tracking-tight">T's Verify Admin</h2>
              <p className={`text-xs mt-1.5 text-center ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                Sign in to manage your payment network
              </p>
            </div>

            <form onSubmit={handleLogin} className="relative space-y-5">
              <div>
                <label className={`block text-[11px] font-semibold uppercase tracking-wider mb-2 ${
                  darkMode ? "text-zinc-400" : "text-zinc-600"
                }`}>Email Address</label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className={`w-full px-4 py-3 rounded-xl border text-sm outline-none transition-all duration-200 ${
                    darkMode
                      ? "bg-white/5 border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                      : "bg-black/5 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                  }`}
                  placeholder="e.g. admin@tspay.com"
                  required
                />
              </div>

              <div>
                <label className={`block text-[11px] font-semibold uppercase tracking-wider mb-2 ${
                  darkMode ? "text-zinc-400" : "text-zinc-600"
                }`}>Password</label>
                <div className="relative">
                  <input
                    type={showPassword ? "text" : "password"}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className={`w-full px-4 py-3 pr-11 rounded-xl border text-sm outline-none transition-all duration-200 ${
                      darkMode
                        ? "bg-white/5 border-white/10 text-white placeholder-zinc-500 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                        : "bg-black/5 border-black/10 text-zinc-900 placeholder-zinc-400 focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20"
                    }`}
                    placeholder="Enter your password"
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

              {error && (
                <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs font-medium animate-scaleIn">
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
                      Authenticating...
                    </span>
                  ) : "Sign In to Admin"}
                </span>
              </button>
            </form>

            <div className={`relative text-center text-[10px] font-mono mt-8 ${darkMode ? "text-zinc-600" : "text-zinc-400"}`}>
              Secure Settlement Portal v1.0.0
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
