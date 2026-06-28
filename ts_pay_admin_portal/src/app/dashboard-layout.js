"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Sidebar from "@/components/Sidebar";
import NotificationBell from "@/components/NotificationBell";
import { SunIcon, MoonIcon, MenuIcon } from "@/components/Icons";
import { Toast } from "@/components/Toast";
import { useToast } from "@/components/Toast";

export default function DashboardLayout({ children, darkMode, setDarkMode }) {
  const router = useRouter();
  const { toast, showToast } = useToast();
  const [email, setEmail] = useState("");
  const [checking, setChecking] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session) {
        router.push("/");
      } else {
        setEmail(session.user.email);
      }
      setChecking(false);
    });
  }, [router]);

  const handleLogout = async () => {
    await supabase.auth.signOut();
    router.push("/");
  };

  if (checking) {
    return (
      <div className="min-h-screen bg-[#080E1A] flex items-center justify-center p-4">
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

  return (
    <div className={`flex h-screen overflow-hidden font-sans transition-colors duration-500 ${
      darkMode ? "bg-[#080E1A] text-zinc-100" : "bg-zinc-50 text-zinc-900"
    }`}>
      <Sidebar
        darkMode={darkMode}
        email={email}
        onLogout={handleLogout}
        mobileOpen={mobileOpen}
        onClose={() => setMobileOpen(false)}
      />
      <main className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <header className={`h-14 sm:h-16 flex items-center justify-between px-4 sm:px-6 lg:px-8 border-b transition-colors duration-300 ${
          darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5"
        }`}>
          <button
            onClick={() => setMobileOpen(true)}
            className={`lg:hidden p-2 rounded-lg transition-colors cursor-pointer ${
              darkMode ? "text-zinc-400 hover:text-white hover:bg-white/5" : "text-zinc-600 hover:text-zinc-950 hover:bg-zinc-100"
            }`}
            aria-label="Open menu"
          >
            <MenuIcon className="w-5 h-5" />
          </button>

          <div className="lg:hidden flex items-center gap-2.5">
            <img src="/logo.png" alt="T's Verify" className="w-7 h-7 object-contain" />
            <span className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>T's Verify</span>
          </div>

          <div className="flex items-center gap-3 ml-auto">
            <NotificationBell darkMode={darkMode} />
            <button
              onClick={() => setDarkMode(!darkMode)}
              className={`p-2 sm:p-2.5 rounded-xl border transition-all cursor-pointer ${
                darkMode
                  ? "bg-white/5 border-white/10 text-amber-400 hover:bg-white/10 hover:text-amber-300"
                  : "bg-black/5 border-black/10 text-zinc-700 hover:bg-black/10 hover:text-zinc-950"
              }`}
              title="Toggle Theme"
            >
              {darkMode ? <SunIcon className="w-4 h-4 sm:w-5 sm:h-5" /> : <MoonIcon className="w-4 h-4 sm:w-5 sm:h-5" />}
            </button>
            <div className={`h-6 w-px ${darkMode ? "bg-white/10" : "bg-black/10"}`} />
            <div className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-[11px] font-semibold transition-all ${
              darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-50 text-emerald-600"
            }`}>
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full rounded-full bg-emerald-500 animate-ping opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
              </span>
              <span className="hidden sm:inline">Online</span>
            </div>
          </div>
        </header>
        <div className={`flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 transition-colors duration-300 ${
          darkMode ? "bg-[#080E1A]" : "bg-zinc-50"
        }`}>
          {children}
        </div>
      </main>
      <Toast toast={toast} darkMode={darkMode} />
    </div>
  );
}
