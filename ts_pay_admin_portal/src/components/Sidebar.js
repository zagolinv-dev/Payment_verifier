"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { SettingsIcon, UsersIcon, CrownIcon, XIcon } from "./Icons";

export default function Sidebar({ darkMode, email, onLogout, mobileOpen, onClose }) {
  const pathname = usePathname();
  const [showConfirm, setShowConfirm] = useState(false);

  const navItems = [
    { href: "/dashboard", label: "Dashboard", icon: DashboardIcon },
    { href: "/approvals", label: "Approvals", icon: ShieldIcon },
    { href: "/companies", label: "Companies", icon: BuildingIcon },
    { href: "/users", label: "Users", icon: UsersIcon },
    { href: "/settings", label: "Settings", icon: SettingsIcon },
  ];

  const isActive = (href) => pathname === href || pathname.startsWith(href + "/");

  const content = (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between mb-8 px-2">
        <Link href="/dashboard" className="flex items-center gap-3 group">
          <div className="relative">
            <div className="absolute inset-0 rounded-xl bg-gradient-to-br from-emerald-400 to-emerald-600 blur-md opacity-50 group-hover:opacity-70 transition-opacity" />
            <img src="/logo.png" alt="T's Verify" className="relative w-9 h-9 object-contain" />
          </div>
          <div>
            <h2 className={`text-base font-bold tracking-tight leading-none ${darkMode ? "text-white" : "text-zinc-950"}`}>T's Verify</h2>
            <span className="text-[8px] text-emerald-500 font-extrabold uppercase tracking-[0.15em] mt-0.5 block">Super Admin</span>
          </div>
        </Link>
        <button
          onClick={onClose}
          className={`lg:hidden p-1.5 rounded-lg transition-colors cursor-pointer ${
            darkMode ? "text-zinc-500 hover:text-white hover:bg-white/5" : "text-zinc-500 hover:text-zinc-900 hover:bg-zinc-100"
          }`}
          aria-label="Close menu"
        >
          <XIcon className="w-5 h-5" />
        </button>
      </div>

      <div className={`relative rounded-xl p-3.5 mb-8 overflow-hidden transition-all duration-300 ${
        darkMode ? "bg-gradient-to-br from-emerald-500/[0.07] to-emerald-500/[0.02] border border-emerald-500/10" : "bg-gradient-to-br from-emerald-50 to-emerald-100/50 border border-emerald-200"
      }`}>
        <div className={`absolute top-0 right-0 w-20 h-20 rounded-full blur-2xl pointer-events-none ${
          darkMode ? "bg-emerald-500/10" : "bg-emerald-500/5"
        }`} />
        <div className="relative flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center shadow-lg shadow-emerald-500/20 flex-shrink-0">
            <CrownIcon className="w-5 h-5 text-zinc-950" />
          </div>
          <div className="min-w-0">
            <div className={`text-xs font-bold truncate ${darkMode ? "text-white" : "text-zinc-800"}`}>Platform Owner</div>
            <div className={`text-[10px] truncate ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>{email || "admin@tspay.com"}</div>
          </div>
        </div>
      </div>

      <nav className="space-y-0.5 flex-1">
        {navItems.map((item) => {
          const active = isActive(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={onClose}
              className={`group relative flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-medium transition-all duration-200 overflow-hidden ${
                active
                  ? darkMode
                    ? "text-emerald-400"
                    : "text-emerald-600"
                  : darkMode
                    ? "text-zinc-400 hover:text-zinc-200"
                    : "text-zinc-500 hover:text-zinc-800"
              }`}
            >
              {active && (
                <span className={`absolute inset-0 rounded-xl transition-all ${
                  darkMode ? "bg-emerald-500/10 border border-emerald-500/15" : "bg-emerald-50 border border-emerald-200"
                }`} />
              )}
              <span className={`relative flex items-center justify-center w-8 h-8 rounded-lg transition-all duration-200 ${
                active
                  ? darkMode
                    ? "bg-emerald-500/15 text-emerald-400"
                    : "bg-emerald-100 text-emerald-600"
                  : darkMode
                    ? "bg-white/5 text-zinc-400 group-hover:bg-white/10 group-hover:text-zinc-200"
                    : "bg-black/5 text-zinc-500 group-hover:bg-black/10 group-hover:text-zinc-800"
              }`}>
                <item.icon className="w-4 h-4" />
              </span>
              <span className="relative">{item.label}</span>
            </Link>
          );
        })}
      </nav>

      <div className={`space-y-0.5 pt-4 border-t mt-4 ${darkMode ? "border-white/10" : "border-black/10"}`}>
        <div className={`px-3.5 py-1.5 text-[9px] font-extrabold uppercase tracking-wider ${darkMode ? "text-zinc-600" : "text-zinc-400"}`}>
          Legal
        </div>
        <Link
          href="/terms"
          onClick={onClose}
          className={`group relative flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-medium transition-all duration-200 ${
            pathname === "/terms"
              ? darkMode
                ? "text-emerald-400 bg-emerald-500/10 border border-emerald-500/15"
                : "text-emerald-600 bg-emerald-50 border border-emerald-200"
              : darkMode
                ? "text-zinc-400 hover:text-zinc-200 hover:bg-white/5"
                : "text-zinc-500 hover:text-zinc-800 hover:bg-black/5"
          }`}
        >
          <span className={`flex items-center justify-center w-8 h-8 rounded-lg transition-all ${
            pathname === "/terms"
              ? darkMode ? "bg-emerald-500/15 text-emerald-400" : "bg-emerald-100 text-emerald-600"
              : darkMode ? "bg-white/5 text-zinc-400" : "bg-black/5 text-zinc-500"
          }`}>
            <DocumentIcon className="w-4 h-4" />
          </span>
          Terms of Service
        </Link>
        <Link
          href="/privacy_policy"
          onClick={onClose}
          className={`group relative flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-medium transition-all duration-200 ${
            pathname === "/privacy_policy"
              ? darkMode
                ? "text-emerald-400 bg-emerald-500/10 border border-emerald-500/15"
                : "text-emerald-600 bg-emerald-50 border border-emerald-200"
              : darkMode
                ? "text-zinc-400 hover:text-zinc-200 hover:bg-white/5"
                : "text-zinc-500 hover:text-zinc-800 hover:bg-black/5"
          }`}
        >
          <span className={`flex items-center justify-center w-8 h-8 rounded-lg transition-all ${
            pathname === "/privacy_policy"
              ? darkMode ? "bg-emerald-500/15 text-emerald-400" : "bg-emerald-100 text-emerald-600"
              : darkMode ? "bg-white/5 text-zinc-400" : "bg-black/5 text-zinc-500"
          }`}>
            <DocumentIcon className="w-4 h-4" />
          </span>
          Privacy Policy
        </Link>
        <button
          onClick={() => setShowConfirm(true)}
          className="group relative w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-medium transition-all duration-200 text-rose-400 hover:bg-rose-500/10 cursor-pointer"
        >
          <span className="flex items-center justify-center w-8 h-8 rounded-lg bg-rose-500/10 text-rose-400 group-hover:bg-rose-500/20 transition-all">
            <LogoutIcon className="w-4 h-4" />
          </span>
          Sign Out
        </button>
      </div>
    </div>
  );

  const confirmModal = showConfirm && (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4" onClick={() => setShowConfirm(false)}>
      <div
        className={`relative w-full max-w-sm rounded-2xl overflow-hidden border shadow-2xl transition-all animate-scaleIn ${
          darkMode ? "bg-[#0F1626] border-white/[0.06]" : "bg-white border-black/5"
        }`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className={`px-6 py-5 border-b ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
          <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Sign Out</h3>
        </div>
        <div className="p-6">
          <div className="flex items-center gap-4 mb-6">
            <div className="w-10 h-10 rounded-xl bg-rose-500/10 text-rose-400 border border-rose-500/20 flex items-center justify-center flex-shrink-0">
              <LogoutIcon className="w-5 h-5" />
            </div>
            <p className={`text-sm ${darkMode ? "text-zinc-300" : "text-zinc-700"}`}>
              Are you sure you want to sign out?
            </p>
          </div>
          <div className="flex gap-3">
            <button
              onClick={() => setShowConfirm(false)}
              className={`flex-1 py-2.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                darkMode ? "bg-white/5 text-zinc-300 hover:bg-white/10" : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"
              }`}
            >
              Cancel
            </button>
            <button
              onClick={() => { setShowConfirm(false); onLogout(); onClose(); }}
              className="flex-1 py-2.5 rounded-xl bg-gradient-to-r from-rose-500 to-rose-600 text-white font-bold text-xs shadow-lg shadow-rose-500/20 hover:from-rose-400 hover:to-rose-500 transition-all cursor-pointer"
            >
              Yes, Sign Out
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <>
      <aside className={`hidden lg:flex w-56 xl:w-64 flex-col p-5 border-r overflow-y-auto transition-all duration-300 ${
        darkMode ? "bg-[#0F1626]/90 border-white/[0.06]" : "bg-white/90 border-black/5 backdrop-blur-xl"
      }`}>
        {content}
      </aside>

      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={onClose} />
          <aside className={`absolute left-0 top-0 bottom-0 w-72 max-w-[85vw] p-5 overflow-y-auto shadow-2xl transition-all ${
            darkMode ? "bg-[#0F1626]" : "bg-white"
          }`}>
            {content}
          </aside>
        </div>
      )}
      {confirmModal}
    </>
  );
}

function DashboardIcon({ className }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
      <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
    </svg>
  );
}

function ShieldIcon({ className }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
    </svg>
  );
}

function BuildingIcon({ className }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
      <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21" />
    </svg>
  );
}

function UserIcon({ className }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
      <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
    </svg>
  );
}

function LogoutIcon({ className }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
      <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9" />
    </svg>
  );
}

function DocumentIcon({ className }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5">
      <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
    </svg>
  );
}
