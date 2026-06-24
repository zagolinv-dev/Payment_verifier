"use client";

import { useState } from "react";

// ── CUSTOM INLINE SVG ICONS (Purged Emojis) ───────────────────────────────────

function CrownIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 3l3.5 6.5L21 8.5l-2.5 7.5H5.5L3 8.5l5.5 1L12 3z" />
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 16v3m-3 0h6" />
    </svg>
  );
}

function CheckCircleIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
  );
}

function XCircleIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
  );
}

function AlertTriangleIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
    </svg>
  );
}

function ChartBarIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
    </svg>
  );
}

function CurrencyEtbIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <rect x="2" y="6" width="20" height="12" rx="2" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="12" cy="12" r="3" strokeLinecap="round" strokeLinejoin="round" />
      <path strokeLinecap="round" strokeLinejoin="round" d="M6 12h.01M18 12h.01" />
    </svg>
  );
}

function OfficeBuildingIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
    </svg>
  );
}

function DocumentTextIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
  );
}

function SearchIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
    </svg>
  );
}

function SaveIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
    </svg>
  );
}

function SunIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <circle cx="12" cy="12" r="5" />
      <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" strokeLinecap="round" />
    </svg>
  );
}

function MoonIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
    </svg>
  );
}

function MenuIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
    </svg>
  );
}

function UserIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
    </svg>
  );
}

function SettingsIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
  );
}

// Option icons
function DatabaseIcon({ className = "w-4 h-4" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" />
    </svg>
  );
}

function TrashIcon({ className = "w-4 h-4" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
    </svg>
  );
}

function LogoutIcon({ className = "w-4 h-4" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
    </svg>
  );
}

function InfoIcon({ className = "w-5 h-5" }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
  );
}

// ── APP CONTAINER ────────────────────────────────────────────────────────────

export default function SuperAdminPortal() {
  const [isLoggedIn, setIsLoggedIn] = useState(true);
  const [loginEmail, setLoginEmail] = useState("admin@tspay.com");
  const [loginPassword, setLoginPassword] = useState("");
  const [loginError, setLoginError] = useState("");

  const [darkMode, setDarkMode] = useState(true);
  const [showMenu, setShowMenu] = useState(false);
  const [selectedTab, setSelectedTab] = useState("dashboard");
  const [searchQuery, setSearchQuery] = useState("");
  const [toast, setToast] = useState({ message: "", type: "info" });
  
  // Platform Settings
  const [settings, setSettings] = useState({
    commissionFee: "1.0",
    minPayout: "5,000",
    ocrConfidence: "85",
    autoVerify: true,
  });

  // Waitress Ledger Data ("who make what" real-time metrics)
  const [waitresses, setWaitresses] = useState([
    { id: "w-1", name: "Martha Gidey", txCount: 42, volume: 154200, tips: 15420, lastActive: "10 mins ago" },
    { id: "w-2", name: "Chala Kebede", txCount: 28, volume: 84300, tips: 8430, lastActive: "1 hour ago" },
    { id: "w-3", name: "Tigist Saladin", txCount: 19, volume: 57000, tips: 5700, lastActive: "3 hours ago" },
    { id: "w-4", name: "Yared Tesfaye", txCount: 12, volume: 38500, tips: 3850, lastActive: "Yesterday" }
  ]);

  // Companies List (Mock Data)
  const [companies, setCompanies] = useState([
    {
      id: "comp-1",
      name: "Habesha Coffee & Lounge",
      owner: "Yonas Alemu",
      email: "yonas@habeshacoffee.com",
      phone: "+251 911 223 344",
      category: "Food & Beverage",
      bankName: "Commercial Bank of Ethiopia (CBE)",
      accountNumber: "1000123456789",
      volume: 820000,
      status: "PENDING",
      submittedAt: "2 hours ago",
      notes: "High-end café located in Bole, Addis Ababa. Processing receipt verifications for daily walk-ins."
    },
    {
      id: "comp-2",
      name: "Gadaa Supermarket",
      owner: "Daniel Tolossa",
      email: "dani@gadaa.com",
      phone: "+251 922 454 566",
      category: "Supermarket",
      bankName: "Awash Bank",
      accountNumber: "01320444555600",
      volume: 2450000,
      status: "PENDING",
      submittedAt: "5 hours ago",
      notes: "Large grocery branch in Saris. Requires multi-terminal validation for cashier checkout codes."
    },
    {
      id: "comp-3",
      name: "Lucy Lounge & Bar",
      owner: "Meron Hagos",
      email: "meron@lucylounge.com",
      phone: "+251 911 556 677",
      category: "Nightlife",
      bankName: "Telebirr",
      accountNumber: "0911556677",
      volume: 450000,
      status: "PENDING",
      submittedAt: "1 day ago",
      notes: "Local bar in Bole Medhanialem. Implementing digital wallet checks for weekend billing."
    },
    {
      id: "comp-4",
      name: "Hilton Addis Restaurant",
      owner: "Tariku Kebede",
      email: "tariku@hiltonaddis.com",
      phone: "+251 911 303 040",
      category: "Hotel & Dining",
      bankName: "Commercial Bank of Ethiopia (CBE)",
      accountNumber: "1000987654321",
      volume: 4890000,
      status: "APPROVED",
      submittedAt: "1 month ago",
      notes: "Hotel dining services validation account. Processing large CBE transactions and tips."
    },
    {
      id: "comp-5",
      name: "Saris Corner Cafe",
      owner: "Tigist Alemu",
      email: "tigist@sariscorner.com",
      phone: "+251 912 345 678",
      category: "Food & Beverage",
      bankName: "Telebirr",
      accountNumber: "0912345678",
      volume: 280000,
      status: "APPROVED",
      submittedAt: "14 days ago",
      notes: "Cozy local coffee corner. Using cashier-level verifications."
    },
    {
      id: "comp-6",
      name: "Kuriftu Resort Settlement",
      owner: "Solomon Kassa",
      email: "solomon@kurifturesorts.com",
      phone: "+251 930 112 233",
      category: "Tourism",
      bankName: "Awash Bank",
      accountNumber: "01420555666700",
      volume: 12450000,
      status: "APPROVED",
      submittedAt: "2 months ago",
      notes: "Luxury resort collection settlement. High volume CBE/Awash integrations."
    },
    {
      id: "comp-7",
      name: "Bole Mall Grocery",
      owner: "Selamawit Gidey",
      email: "selam@bolemall.com",
      phone: "+251 911 889 900",
      category: "Supermarket",
      bankName: "CBE Birr",
      accountNumber: "911889900",
      volume: 650000,
      status: "SUSPENDED",
      submittedAt: "3 weeks ago",
      notes: "Bole mall food court branch. Currently suspended due to registration document reissue."
    }
  ]);

  const [activeReviewCompany, setActiveReviewCompany] = useState(null);

  // Helper: Trigger custom toast notification
  const showToast = (message, type = "success") => {
    setToast({ message, type });
    setTimeout(() => {
      setToast({ message: "", type: "info" });
    }, 4000);
  };

  // Login submission
  const handleLogin = (e) => {
    e.preventDefault();
    if (!loginEmail.includes("@")) {
      setLoginError("Please enter a valid email address.");
      return;
    }
    if (loginPassword.length < 4) {
      setLoginError("Password must be at least 4 characters.");
      return;
    }
    setLoginError("");
    setIsLoggedIn(true);
    showToast("Authentication successful! Welcome to Super Admin portal.", "success");
  };

  // Actions
  const handleApprove = (id) => {
    setCompanies(prev =>
      prev.map(c => c.id === id ? { ...c, status: "APPROVED" } : c)
    );
    const company = companies.find(c => c.id === id);
    showToast(`${company.name} has been approved successfully!`, "success");
    setActiveReviewCompany(null);
  };

  const handleReject = (id) => {
    setCompanies(prev =>
      prev.map(c => c.id === id ? { ...c, status: "REJECTED" } : c)
    );
    const company = companies.find(c => c.id === id);
    showToast(`${company.name} registration request has been rejected.`, "error");
    setActiveReviewCompany(null);
  };

  const handleToggleSuspend = (id) => {
    setCompanies(prev =>
      prev.map(c => {
        if (c.id === id) {
          const isSuspended = c.status === "SUSPENDED";
          const newStatus = isSuspended ? "APPROVED" : "SUSPENDED";
          showToast(isSuspended 
            ? `${c.name} has been re-activated with full platform access.`
            : `${c.name} has been suspended. All terminal integrations locked.`, 
            isSuspended ? "success" : "warning"
          );
          return { ...c, status: newStatus };
        }
        return c;
      })
    );
  };

  // Statistics Computations
  const pendingCompanies = companies.filter(c => c.status === "PENDING");
  const approvedCompanies = companies.filter(c => c.status === "APPROVED");
  const totalVolume = approvedCompanies.reduce((acc, c) => acc + c.volume, 0);
  const totalPlatformFees = totalVolume * (parseFloat(settings.commissionFee) / 100);

  // Filters
  const filteredActiveCompanies = approvedCompanies.filter(c =>
    c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    c.owner.toLowerCase().includes(searchQuery.toLowerCase()) ||
    c.email.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // ── RENDER AUTH PAGE IF LOGGED OUT ──────────────────────────────────────────
  if (!isLoggedIn) {
    return (
      <div className={`min-h-screen flex items-center justify-center font-sans transition-colors duration-300 ${
        darkMode ? "bg-[#080E1A] text-zinc-100" : "bg-zinc-50 text-zinc-900"
      }`}>
        <div className="absolute top-6 right-6">
          <button
            onClick={() => setDarkMode(!darkMode)}
            className={`p-3 rounded-full border transition-all cursor-pointer ${
              darkMode 
                ? "bg-[#0F1626] border-[#1E2D47] text-amber-400 hover:text-amber-300" 
                : "bg-white border-zinc-200 text-zinc-700 hover:text-zinc-950 shadow-sm"
            }`}
          >
            {darkMode ? <SunIcon className="w-5 h-5" /> : <MoonIcon className="w-5 h-5" />}
          </button>
        </div>

        <div className="w-full max-w-md p-2">
          <div className={`rounded-3xl border p-8 shadow-2xl transition-all duration-300 ${
            darkMode 
              ? "bg-[#0F1626] border-[#1E2D47] shadow-black/80" 
              : "bg-white border-zinc-200 shadow-zinc-200"
          }`}>
            {/* Header logo */}
            <div className="flex flex-col items-center mb-8">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center shadow-lg shadow-emerald-500/20 mb-4">
                <span className="text-2xl font-extrabold text-[#080E1A]">T</span>
              </div>
              <h2 className="text-xl font-bold tracking-tight">T's Pay Admin</h2>
              <p className={`text-xs mt-1 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Super Admin credentials required for authentication</p>
            </div>

            <form onSubmit={handleLogin} className="space-y-5">
              <div>
                <label className={`block text-xs font-bold uppercase tracking-wider mb-2 ${
                  darkMode ? "text-zinc-400" : "text-zinc-600"
                }`}>Email Address</label>
                <input
                  type="email"
                  value={loginEmail}
                  onChange={(e) => setLoginEmail(e.target.value)}
                  className={`w-full px-4 py-3 rounded-xl border text-sm outline-none transition-all ${
                    darkMode 
                      ? "bg-[#080E1A] border-[#1E2D47] text-white focus:border-emerald-500" 
                      : "bg-zinc-50 border-zinc-200 text-zinc-900 focus:border-emerald-500"
                  }`}
                  placeholder="e.g. admin@tspay.com"
                  required
                />
              </div>

              <div>
                <label className={`block text-xs font-bold uppercase tracking-wider mb-2 ${
                  darkMode ? "text-zinc-400" : "text-zinc-600"
                }`}>Access Password</label>
                <input
                  type="password"
                  value={loginPassword}
                  onChange={(e) => setLoginPassword(e.target.value)}
                  className={`w-full px-4 py-3 rounded-xl border text-sm outline-none transition-all ${
                    darkMode 
                      ? "bg-[#080E1A] border-[#1E2D47] text-white focus:border-emerald-500" 
                      : "bg-zinc-50 border-zinc-200 text-zinc-900 focus:border-emerald-500"
                  }`}
                  placeholder="Enter administrator password"
                  required
                />
              </div>

              {loginError && (
                <div className="p-3 bg-rose-500/10 border border-rose-500/20 text-rose-500 text-xs rounded-lg font-medium">
                  {loginError}
                </div>
              )}

              <button
                type="submit"
                className="w-full py-3.5 mt-2 bg-gradient-to-br from-emerald-400 to-emerald-600 text-zinc-950 font-bold rounded-xl shadow-lg shadow-emerald-500/10 hover:opacity-95 transition-all cursor-pointer text-sm"
              >
                Sign In to Admin
              </button>
            </form>

            <div className={`text-center text-[10px] font-mono mt-8 ${
              darkMode ? "text-zinc-500" : "text-zinc-400"
            }`}>
              Secure Settlement Portal v1.0.0
            </div>
          </div>
        </div>
      </div>
    );
  }

  // ── RENDER SUPER ADMIN PORTAL ──────────────────────────────────────────────
  return (
    <div className={`flex h-screen overflow-hidden font-sans transition-colors duration-300 ${
      darkMode ? "bg-[#080E1A] text-zinc-100" : "bg-zinc-50 text-zinc-900"
    }`}>
      
      {/* Toast Notification */}
      {toast.message && (
        <div className={`fixed bottom-6 right-6 z-50 flex items-center gap-3 border px-5 py-4 rounded-xl shadow-2xl animate-bounce ${
          toast.type === "success" ? "bg-emerald-500/10 border-emerald-500/30 text-emerald-400" :
          toast.type === "error" ? "bg-rose-500/10 border-rose-500/30 text-rose-500" :
          toast.type === "warning" ? "bg-amber-500/10 border-amber-500/30 text-amber-500" :
          "bg-zinc-500/10 border-zinc-500/30 text-zinc-500"
        }`}>
          {toast.type === "success" && <CheckCircleIcon className="w-5 h-5" />}
          {toast.type === "error" && <XCircleIcon className="w-5 h-5" />}
          {toast.type === "warning" && <AlertTriangleIcon className="w-5 h-5" />}
          {toast.type === "info" && <InfoIcon className="w-5 h-5" />}
          <div className="text-sm font-semibold tracking-wide">{toast.message}</div>
        </div>
      )}

      {/* ── SIDEBAR ────────────────────────────────────────────────────────── */}
      <aside className={`w-72 flex flex-col justify-between p-6 border-r transition-all duration-300 ${
        darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
      }`}>
        <div>
          {/* Brand Logo */}
          <div className="flex items-center gap-3 mb-10 px-2">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center shadow-lg shadow-emerald-500/25">
              <span className="text-xl font-extrabold text-[#080E1A]">T</span>
            </div>
            <div>
              <h2 className={`text-lg font-bold tracking-tight leading-none ${darkMode ? "text-white" : "text-zinc-950"}`}>T's Pay</h2>
              <span className="text-[9px] text-emerald-500 font-extrabold uppercase tracking-widest mt-1 block">Super Admin</span>
            </div>
          </div>

          {/* Profile Card */}
          <div className={`rounded-xl p-4 border mb-8 transition-all ${
            darkMode ? "bg-[#182235] border-[#1E2D47]" : "bg-zinc-100/80 border-zinc-200"
          }`}>
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-full bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center text-zinc-950">
                <CrownIcon className="w-5 h-5" />
              </div>
              <div>
                <div className={`text-xs font-bold ${darkMode ? "text-white" : "text-zinc-800"}`}>Platform Owner</div>
                <div className={`text-[10px] ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>admin@tspay.com</div>
              </div>
            </div>
          </div>

          {/* Nav Items */}
          <nav className="space-y-1">
            <button
              onClick={() => setSelectedTab("dashboard")}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all cursor-pointer ${
                selectedTab === "dashboard"
                  ? darkMode 
                    ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"
                    : "bg-emerald-50 text-emerald-600 border border-emerald-100"
                  : darkMode 
                    ? "text-zinc-400 hover:text-white hover:bg-white/5" 
                    : "text-zinc-600 hover:text-zinc-950 hover:bg-zinc-100"
              }`}
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2v-4zM14 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2v-4z" />
              </svg>
              Dashboard Overview
            </button>

            <button
              onClick={() => setSelectedTab("approvals")}
              className={`w-full flex items-center justify-between px-4 py-3 rounded-xl text-sm font-medium transition-all cursor-pointer ${
                selectedTab === "approvals"
                  ? darkMode 
                    ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"
                    : "bg-emerald-50 text-emerald-600 border border-emerald-100"
                  : darkMode 
                    ? "text-zinc-400 hover:text-white hover:bg-white/5" 
                    : "text-zinc-600 hover:text-zinc-950 hover:bg-zinc-100"
              }`}
            >
              <div className="flex items-center gap-3">
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                </svg>
                Merchant Approvals
              </div>
              {pendingCompanies.length > 0 && (
                <span className="bg-amber-500 text-[#080E1A] font-extrabold text-[10px] px-2 py-0.5 rounded-full">
                  {pendingCompanies.length}
                </span>
              )}
            </button>

            <button
              onClick={() => setSelectedTab("active")}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all cursor-pointer ${
                selectedTab === "active"
                  ? darkMode 
                    ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"
                    : "bg-emerald-50 text-emerald-600 border border-emerald-100"
                  : darkMode 
                    ? "text-zinc-400 hover:text-white hover:bg-white/5" 
                    : "text-zinc-600 hover:text-zinc-950 hover:bg-zinc-100"
              }`}
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                <path strokeLinecap="round" strokeLinejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              Active Companies
            </button>

            <button
              onClick={() => setSelectedTab("settings")}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all cursor-pointer ${
                selectedTab === "settings"
                  ? darkMode 
                    ? "bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"
                    : "bg-emerald-50 text-emerald-600 border border-emerald-100"
                  : darkMode 
                    ? "text-zinc-400 hover:text-white hover:bg-white/5" 
                    : "text-zinc-600 hover:text-zinc-950 hover:bg-zinc-100"
              }`}
            >
              <SettingsIcon className="w-5 h-5" />
              Platform Settings
            </button>
          </nav>
        </div>

        <div className={`text-[10px] text-center font-mono ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
          T's Pay Administration Portal v1.0.0
        </div>
      </aside>

      {/* ── MAIN CONTENT AREA ────────────────────────────────────────────────── */}
      <main className="flex-1 flex flex-col min-w-0 overflow-hidden">
        
        {/* Top Header */}
        <header className={`h-20 flex items-center justify-between px-8 border-b transition-colors duration-300 relative z-30 ${
          darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200"
        }`}>
          <div>
            <h1 className={`text-xl font-bold tracking-tight ${darkMode ? "text-white" : "text-zinc-900"}`}>
              {selectedTab === "dashboard" && "SaaS Platform Overview"}
              {selectedTab === "approvals" && "Merchant Registration Approvals"}
              {selectedTab === "active" && "Approved Companies Ledger"}
              {selectedTab === "settings" && "Global Commission & Rules"}
            </h1>
            <p className={`text-xs mt-1 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
              Super Admin controls for consolidated payment settlement networks.
            </p>
          </div>

          <div className="flex items-center gap-4">
            {/* Theme Toggle Button */}
            <button
              onClick={() => setDarkMode(!darkMode)}
              className={`p-2.5 rounded-full border transition-all cursor-pointer ${
                darkMode 
                  ? "bg-[#182235] border-[#1E2D47] text-amber-400 hover:text-amber-300" 
                  : "bg-zinc-100 border-zinc-200 text-zinc-700 hover:text-zinc-950 shadow-sm"
              }`}
              title="Toggle Bright/Dark Mode"
            >
              {darkMode ? <SunIcon className="w-5 h-5" /> : <MoonIcon className="w-5 h-5" />}
            </button>

            {/* Separator */}
            <div className={`w-px h-8 ${darkMode ? "bg-[#1E2D47]" : "bg-zinc-200"}`} />

            {/* Menu Options Button */}
            <div className="relative">
              <button
                onClick={() => setShowMenu(!showMenu)}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl border text-xs font-semibold tracking-wide transition-all cursor-pointer ${
                  darkMode 
                    ? "bg-[#182235] border-[#1E2D47] text-zinc-100 hover:bg-[#202E48]" 
                    : "bg-zinc-100 border-zinc-200 text-zinc-700 hover:bg-zinc-200 shadow-sm"
                }`}
              >
                <MenuIcon className="w-4 h-4" />
                <span>Options</span>
              </button>

              {/* Header Dropdown Menu */}
              {showMenu && (
                <>
                  <div className="fixed inset-0 z-40" onClick={() => setShowMenu(false)} />
                  <div className={`absolute right-0 mt-2.5 w-60 rounded-2xl border p-2 shadow-2xl z-50 animate-fadeIn ${
                    darkMode 
                      ? "bg-[#0F1626] border-[#1E2D47] text-zinc-100" 
                      : "bg-white border-zinc-200 text-zinc-800"
                  }`}>
                    <div className={`px-3 py-2 border-b text-[11px] font-bold ${
                      darkMode ? "border-[#1E2D47]/60 text-zinc-400" : "border-zinc-100 text-zinc-500"
                    }`}>
                      LOGGED IN AS
                      <span className={`block font-semibold text-xs mt-0.5 truncate ${darkMode ? "text-white" : "text-zinc-800"}`}>
                        admin@tspay.com
                      </span>
                    </div>
                    <div className="py-1">
                      <button
                        onClick={() => { setSelectedTab("settings"); setShowMenu(false); }}
                        className={`w-full flex items-center gap-2.5 px-3 py-2 text-xs rounded-lg transition-all cursor-pointer ${
                          darkMode ? "hover:bg-white/5 text-zinc-300 hover:text-white" : "hover:bg-zinc-100 text-zinc-700 hover:text-zinc-950"
                        }`}
                      >
                        <SettingsIcon className="w-4 h-4" />
                        System Settings
                      </button>
                      <button
                        onClick={() => { setSelectedTab("approvals"); setShowMenu(false); }}
                        className={`w-full flex items-center justify-between px-3 py-2 text-xs rounded-lg transition-all cursor-pointer ${
                          darkMode ? "hover:bg-white/5 text-zinc-300 hover:text-white" : "hover:bg-zinc-100 text-zinc-700 hover:text-zinc-950"
                        }`}
                      >
                        <div className="flex items-center gap-2.5">
                          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2">
                            <path strokeLinecap="round" strokeLinejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                          </svg>
                          Merchant Approvals
                        </div>
                        {pendingCompanies.length > 0 && (
                          <span className="bg-amber-500 text-[#080E1A] font-extrabold text-[9px] px-1.5 py-0.2 rounded-full">
                            {pendingCompanies.length}
                          </span>
                        )}
                      </button>
                      <button
                        onClick={() => {
                          showToast("Database backup archive generated and stored safely.", "success");
                          setShowMenu(false);
                        }}
                        className={`w-full flex items-center gap-2.5 px-3 py-2 text-xs rounded-lg transition-all cursor-pointer ${
                          darkMode ? "hover:bg-white/5 text-zinc-300 hover:text-white" : "hover:bg-zinc-100 text-zinc-700 hover:text-zinc-950"
                        }`}
                      >
                        <DatabaseIcon className="w-4 h-4" />
                        Trigger DB Backup
                      </button>
                      <button
                        onClick={() => {
                          showToast("All system audit logs cleared.", "warning");
                          setShowMenu(false);
                        }}
                        className={`w-full flex items-center gap-2.5 px-3 py-2 text-xs rounded-lg transition-all cursor-pointer ${
                          darkMode ? "hover:bg-white/5 text-zinc-300 hover:text-white" : "hover:bg-zinc-100 text-zinc-700 hover:text-zinc-950"
                        }`}
                      >
                        <TrashIcon className="w-4 h-4" />
                        Purge Audit Logs
                      </button>
                    </div>
                    <div className={`border-t py-1 mt-1 ${darkMode ? "border-[#1E2D47]/60" : "border-zinc-100"}`}>
                      <button
                        onClick={() => {
                          setIsLoggedIn(false);
                          setShowMenu(false);
                          showToast("Logged out successfully from Super Admin portal.", "info");
                        }}
                        className="w-full flex items-center gap-2.5 px-3 py-2 text-xs rounded-lg transition-all hover:bg-rose-500/10 text-rose-500 cursor-pointer font-semibold"
                      >
                        <LogoutIcon className="w-4 h-4 text-rose-500" />
                        Sign Out
                      </button>
                    </div>
                  </div>
                </>
              )}
            </div>

            {/* Separator */}
            <div className={`w-px h-8 ${darkMode ? "bg-[#1E2D47]" : "bg-zinc-200"}`} />

            <span className={`inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-bold transition-all ${
              darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-50 text-emerald-600 border border-emerald-100"
            }`}>
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              Online
            </span>
          </div>
        </header>

        {/* Dynamic Pages */}
        <div className={`flex-1 overflow-y-auto p-8 transition-colors duration-300 ${
          darkMode ? "bg-[#080E1A]" : "bg-zinc-50"
        }`}>
          
          {/* TAB 1: DASHBOARD */}
          {selectedTab === "dashboard" && (
            <div className="space-y-8 animate-fadeIn">
              
              {/* KPI Cards Row */}
              <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                
                {/* Volume Card */}
                <div className={`border p-6 rounded-2xl relative overflow-hidden group transition-all duration-300 ${
                  darkMode 
                    ? "bg-[#0F1626] border-[#1E2D47] hover:border-emerald-500/40 shadow-black/30" 
                    : "bg-white border-zinc-200 hover:border-emerald-500/40 shadow-sm shadow-zinc-200"
                }`}>
                  <div className={`text-xs font-bold uppercase tracking-wider ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Processed Volume</div>
                  <div className="text-2xl font-bold mt-2 font-mono">
                    {totalVolume.toLocaleString()} <span className="text-sm font-bold text-emerald-500">ETB</span>
                  </div>
                  <div className="text-[10px] text-emerald-500 font-semibold mt-2 flex items-center gap-1">
                    <span>↑ 14.8% this week</span>
                  </div>
                  <div className={`absolute right-4 bottom-4 opacity-5 transition-transform duration-300 group-hover:scale-110 ${
                    darkMode ? "text-white" : "text-zinc-900"
                  }`}>
                    <ChartBarIcon className="w-16 h-16" />
                  </div>
                </div>

                {/* Revenue Card */}
                <div className={`border p-6 rounded-2xl relative overflow-hidden group transition-all duration-300 ${
                  darkMode 
                    ? "bg-[#0F1626] border-[#1E2D47] hover:border-amber-500/40 shadow-black/30" 
                    : "bg-white border-zinc-200 hover:border-amber-500/40 shadow-sm shadow-zinc-200"
                }`}>
                  <div className={`text-xs font-bold uppercase tracking-wider ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                    Platform Revenue ({settings.commissionFee}%)
                  </div>
                  <div className="text-2xl font-bold mt-2 font-mono text-amber-500">
                    {totalPlatformFees.toLocaleString(undefined, { maximumFractionDigits: 2 })} <span className="text-sm font-bold">ETB</span>
                  </div>
                  <div className={`text-[10px] mt-2 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                    Accruing platform settlement fee
                  </div>
                  <div className={`absolute right-4 bottom-4 opacity-5 transition-transform duration-300 group-hover:scale-110 ${
                    darkMode ? "text-white" : "text-zinc-900"
                  }`}>
                    <CurrencyEtbIcon className="w-16 h-16" />
                  </div>
                </div>

                {/* Active Merchants Card */}
                <div className={`border p-6 rounded-2xl relative overflow-hidden group transition-all duration-300 ${
                  darkMode 
                    ? "bg-[#0F1626] border-[#1E2D47] hover:border-emerald-500/40 shadow-black/30" 
                    : "bg-white border-zinc-200 hover:border-emerald-500/40 shadow-sm shadow-zinc-200"
                }`}>
                  <div className={`text-xs font-bold uppercase tracking-wider ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Active Merchants</div>
                  <div className="text-2xl font-bold mt-2 font-mono">
                    {approvedCompanies.length} <span className={`text-sm font-normal ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Companies</span>
                  </div>
                  <div className="text-[10px] text-emerald-500 mt-2 font-semibold">94% active terminal state</div>
                  <div className={`absolute right-4 bottom-4 opacity-5 transition-transform duration-300 group-hover:scale-110 ${
                    darkMode ? "text-white" : "text-zinc-900"
                  }`}>
                    <OfficeBuildingIcon className="w-16 h-16" />
                  </div>
                </div>

                {/* Pending Card */}
                <div className={`border p-6 rounded-2xl relative overflow-hidden group transition-all duration-300 ${
                  darkMode 
                    ? "bg-[#0F1626] border-[#1E2D47] hover:border-amber-500/40 shadow-black/30" 
                    : "bg-white border-zinc-200 hover:border-amber-500/40 shadow-sm shadow-zinc-200"
                }`}>
                  <div className={`text-xs font-bold uppercase tracking-wider ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Pending Registrations</div>
                  <div className="text-2xl font-bold mt-2 font-mono text-amber-500">
                    {pendingCompanies.length} <span className={`text-sm font-normal ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Awaiting</span>
                  </div>
                  <div className={`text-[10px] mt-2 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                    Requires credentials review
                  </div>
                  <div className={`absolute right-4 bottom-4 opacity-5 transition-transform duration-300 group-hover:scale-110 ${
                    darkMode ? "text-white" : "text-zinc-900"
                  }`}>
                    <DocumentTextIcon className="w-16 h-16" />
                  </div>
                </div>

              </div>

              {/* Chart Grid Row 1 */}
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                
                {/* SVG Area Chart */}
                <div className={`border p-6 rounded-2xl lg:col-span-2 transition-all ${
                  darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
                }`}>
                  <div className="flex justify-between items-center mb-6">
                    <h3 className={`text-xs font-bold uppercase tracking-wider ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                      Overall Transaction Volume Trend (7 Days)
                    </h3>
                    <span className={`text-xs font-bold px-2 py-0.5 rounded ${
                      darkMode ? "text-emerald-400 bg-emerald-500/10" : "text-emerald-600 bg-emerald-50"
                    }`}>
                      ETB Millions
                    </span>
                  </div>
                  <div className="relative h-64 w-full">
                    <svg className="w-full h-full" viewBox="0 0 600 200" preserveAspectRatio="none">
                      <defs>
                        <linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="#10b981" stopOpacity="0.4" />
                          <stop offset="100%" stopColor="#10b981" stopOpacity="0.0" />
                        </linearGradient>
                      </defs>
                      {/* Grid Lines */}
                      <line x1="0" y1="50" x2="600" y2="50" stroke={darkMode ? "#1E2D47" : "#E4E4E7"} strokeWidth="0.5" strokeDasharray="5" />
                      <line x1="0" y1="100" x2="600" y2="100" stroke={darkMode ? "#1E2D47" : "#E4E4E7"} strokeWidth="0.5" strokeDasharray="5" />
                      <line x1="0" y1="150" x2="600" y2="150" stroke={darkMode ? "#1E2D47" : "#E4E4E7"} strokeWidth="0.5" strokeDasharray="5" />
                      
                      {/* Area Fill */}
                      <path
                        d="M0,200 L0,140 Q100,80 200,110 T400,60 T600,40 L600,200 Z"
                        fill="url(#chartGrad)"
                      />
                      
                      {/* Path Line */}
                      <path
                        d="M0,140 Q100,80 200,110 T400,60 T600,40"
                        fill="none"
                        stroke="#10b981"
                        strokeWidth="3"
                        strokeLinecap="round"
                      />
                      
                      {/* Data Dots */}
                      <circle cx="200" cy="110" r="5" fill="#f59e0b" stroke={darkMode ? "#0F1626" : "#fff"} strokeWidth="1.5" />
                      <circle cx="400" cy="60" r="5" fill="#f59e0b" stroke={darkMode ? "#0F1626" : "#fff"} strokeWidth="1.5" />
                      <circle cx="600" cy="40" r="5" fill="#f59e0b" stroke={darkMode ? "#0F1626" : "#fff"} strokeWidth="1.5" />
                    </svg>
                    
                    {/* X Axis Labels */}
                    <div className={`flex justify-between text-[9px] font-mono mt-3 ${
                      darkMode ? "text-zinc-500" : "text-zinc-400"
                    }`}>
                      <span>June 18</span>
                      <span>June 19</span>
                      <span>June 20</span>
                      <span>June 21</span>
                      <span>June 22</span>
                      <span>June 23</span>
                      <span>Today</span>
                    </div>
                  </div>
                </div>

                {/* Bank / Wallet Distribution */}
                <div className={`border p-6 rounded-2xl transition-all ${
                  darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
                }`}>
                  <h3 className={`text-xs font-bold uppercase tracking-wider mb-6 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                    Settlement Wallet Distribution
                  </h3>
                  <div className="space-y-4">
                    
                    <div>
                      <div className="flex justify-between text-xs font-semibold mb-1.5">
                        <span className={darkMode ? "text-zinc-200" : "text-zinc-700"}>Commercial Bank of Ethiopia (CBE)</span>
                        <span className="font-mono text-zinc-400">55%</span>
                      </div>
                      <div className={`w-full h-2 rounded-full overflow-hidden ${darkMode ? "bg-[#1E2D47]" : "bg-zinc-100"}`}>
                        <div className="h-full bg-gradient-to-r from-emerald-400 to-emerald-600" style={{ width: "55%" }} />
                      </div>
                    </div>

                    <div>
                      <div className="flex justify-between text-xs font-semibold mb-1.5">
                        <span className={darkMode ? "text-zinc-200" : "text-zinc-700"}>Telebirr Mobile Wallet</span>
                        <span className="font-mono text-zinc-400">30%</span>
                      </div>
                      <div className={`w-full h-2 rounded-full overflow-hidden ${darkMode ? "bg-[#1E2D47]" : "bg-zinc-100"}`}>
                        <div className="h-full bg-gradient-to-r from-amber-400 to-amber-600" style={{ width: "30%" }} />
                      </div>
                    </div>

                    <div>
                      <div className="flex justify-between text-xs font-semibold mb-1.5">
                        <span className={darkMode ? "text-zinc-200" : "text-zinc-700"}>Awash Bank Transfers</span>
                        <span className="font-mono text-zinc-400">10%</span>
                      </div>
                      <div className={`w-full h-2 rounded-full overflow-hidden ${darkMode ? "bg-[#1E2D47]" : "bg-zinc-100"}`}>
                        <div className="h-full bg-blue-500" style={{ width: "10%" }} />
                      </div>
                    </div>

                    <div>
                      <div className="flex justify-between text-xs font-semibold mb-1.5">
                        <span className={darkMode ? "text-zinc-200" : "text-zinc-700"}>CBE Birr Wallet</span>
                        <span className="font-mono text-zinc-400">5%</span>
                      </div>
                      <div className={`w-full h-2 rounded-full overflow-hidden ${darkMode ? "bg-[#1E2D47]" : "bg-zinc-100"}`}>
                        <div className="h-full bg-emerald-700" style={{ width: "5%" }} />
                      </div>
                    </div>

                  </div>
                </div>

              </div>

              {/* Chart Grid Row 2 (NEW GRAPH ANALYTICS) */}
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                
                {/* Graph A: Weekly Bank Transactions Volume Chart */}
                <div className={`border p-6 rounded-2xl transition-all ${
                  darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
                }`}>
                  <h3 className={`text-xs font-bold uppercase tracking-wider mb-5 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                    Weekly Transaction Count by Wallet
                  </h3>
                  <div className="h-48 flex items-end justify-around pb-2 relative">
                    {/* SVG column bars */}
                    <div className="flex flex-col items-center group w-1/4">
                      <div className={`text-[10px] font-bold mb-1 opacity-0 group-hover:opacity-100 transition-opacity font-mono`}>1,240</div>
                      <div className="w-10 bg-emerald-500 rounded-t-lg transition-all duration-500 hover:opacity-85" style={{ height: "120px" }} />
                      <div className={`text-[10px] font-bold mt-2 font-mono truncate max-w-full`}>CBE</div>
                    </div>

                    <div className="flex flex-col items-center group w-1/4">
                      <div className={`text-[10px] font-bold mb-1 opacity-0 group-hover:opacity-100 transition-opacity font-mono`}>890</div>
                      <div className="w-10 bg-amber-500 rounded-t-lg transition-all duration-500 hover:opacity-85" style={{ height: "90px" }} />
                      <div className={`text-[10px] font-bold mt-2 font-mono truncate max-w-full`}>Telebirr</div>
                    </div>

                    <div className="flex flex-col items-center group w-1/4">
                      <div className={`text-[10px] font-bold mb-1 opacity-0 group-hover:opacity-100 transition-opacity font-mono`}>320</div>
                      <div className="w-10 bg-blue-500 rounded-t-lg transition-all duration-500 hover:opacity-85" style={{ height: "35px" }} />
                      <div className={`text-[10px] font-bold mt-2 font-mono truncate max-w-full`}>Awash</div>
                    </div>

                    <div className="flex flex-col items-center group w-1/4">
                      <div className={`text-[10px] font-bold mb-1 opacity-0 group-hover:opacity-100 transition-opacity font-mono`}>150</div>
                      <div className="w-10 bg-emerald-700 rounded-t-lg transition-all duration-500 hover:opacity-85" style={{ height: "20px" }} />
                      <div className={`text-[10px] font-bold mt-2 font-mono truncate max-w-full`}>CBE Birr</div>
                    </div>
                  </div>
                  <p className={`text-[10px] text-center mt-3 font-mono ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                    Comparison metrics based on 7-day verified sessions.
                  </p>
                </div>

                {/* Graph B: Verification Status Radial Success Donut */}
                <div className={`border p-6 rounded-2xl transition-all ${
                  darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
                }`}>
                  <h3 className={`text-xs font-bold uppercase tracking-wider mb-4 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                    Verification Success Rate
                  </h3>
                  <div className="flex items-center justify-center h-44">
                    <svg className="w-36 h-36 transform -rotate-90" viewBox="0 0 36 36">
                      {/* Gray track background */}
                      <circle cx="18" cy="18" r="15.915" fill="none" stroke={darkMode ? "#1E2D47" : "#F4F4F5"} strokeWidth="3" />
                      
                      {/* Success sector: 94.2% */}
                      <circle 
                        cx="18" cy="18" r="15.915" 
                        fill="none" 
                        stroke="#10b981" 
                        strokeWidth="3.2" 
                        strokeDasharray="94.2 5.8" 
                        strokeDashoffset="0" 
                      />

                      {/* Center labels */}
                      <g className="transform rotate-90 origin-center">
                        <text x="50%" y="45%" dominantBaseline="middle" textAnchor="middle" className={`text-[6px] font-extrabold font-mono`} fill={darkMode ? "#fff" : "#18181B"}>
                          94.2%
                        </text>
                        <text x="50%" y="65%" dominantBaseline="middle" textAnchor="middle" className={`text-[2.2px] font-bold uppercase tracking-wider`} fill={darkMode ? "#9CA3AF" : "#71717A"}>
                          SUCCESS RATE
                        </text>
                      </g>
                    </svg>
                  </div>
                  <div className="flex justify-center gap-4 text-[10px] font-semibold mt-1">
                    <span className="flex items-center gap-1"><span className="w-2 h-2 bg-emerald-500 rounded-full" /> Verified</span>
                    <span className="flex items-center gap-1"><span className="w-2 h-2 bg-rose-500 rounded-full" /> Failed</span>
                    <span className="flex items-center gap-1"><span className="w-2 h-2 bg-amber-500 rounded-full" /> Pending</span>
                  </div>
                </div>

                {/* Graph C: Who Made What Waitress Session Performance Card */}
                <div className={`border p-6 rounded-2xl transition-all ${
                  darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
                }`}>
                  <h3 className={`text-xs font-bold uppercase tracking-wider mb-5 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                    Waitress Verification Ledger
                  </h3>
                  <div className="space-y-3.5">
                    {waitresses.map((waitress) => (
                      <div key={waitress.id} className="flex items-center justify-between text-xs">
                        <div className="flex items-center gap-2">
                          <div className={`w-6 h-6 rounded-full flex items-center justify-center text-[10px] font-bold bg-emerald-500/10 text-emerald-500 border border-emerald-500/20`}>
                            {waitress.name[0]}
                          </div>
                          <div>
                            <span className="font-bold block leading-tight">{waitress.name}</span>
                            <span className={`text-[9px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{waitress.txCount} txns</span>
                          </div>
                        </div>
                        <div className="text-right">
                          <span className="font-mono font-bold block">{waitress.volume.toLocaleString()} ETB</span>
                          <span className="text-[9px] text-amber-500 font-semibold">+{waitress.tips.toLocaleString()} tips</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

              </div>

              {/* Recent Actions / Audits */}
              <div className={`border rounded-2xl p-6 transition-all ${
                darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
              }`}>
                <h3 className={`text-xs font-bold uppercase tracking-wider mb-6 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                  Recent System Audit Log
                </h3>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead>
                      <tr className={`border-b text-zinc-400 font-bold uppercase tracking-wider ${
                        darkMode ? "border-[#1E2D47]" : "border-zinc-200"
                      }`}>
                        <th className="pb-3">Action Type</th>
                        <th className="pb-3">Target Merchant</th>
                        <th className="pb-3">Operator</th>
                        <th className="pb-3">Status / Result</th>
                        <th className="pb-3 text-right">Timestamp</th>
                      </tr>
                    </thead>
                    <tbody className={`divide-y font-medium ${
                      darkMode ? "divide-[#1E2D47]/40 text-zinc-300" : "divide-zinc-100 text-zinc-700"
                    }`}>
                      <tr className={darkMode ? "hover:bg-white/[0.01]" : "hover:bg-zinc-50/50"}>
                        <td className="py-3 font-bold">Approve Registration</td>
                        <td>Kuriftu Resort Settlement</td>
                        <td>Super Admin</td>
                        <td>
                          <span className={`px-2 py-0.5 rounded text-[9px] font-extrabold uppercase tracking-wider bg-emerald-500/10 text-emerald-400`}>
                            APPROVED
                          </span>
                        </td>
                        <td className="py-3 text-right font-mono text-zinc-500">2026-06-24 14:15</td>
                      </tr>
                      <tr className={darkMode ? "hover:bg-white/[0.01]" : "hover:bg-zinc-50/50"}>
                        <td className="py-3 font-bold">Suspend Account</td>
                        <td>Bole Mall Grocery</td>
                        <td>Super Admin</td>
                        <td>
                          <span className={`px-2 py-0.5 rounded text-[9px] font-extrabold uppercase tracking-wider bg-rose-500/10 text-rose-500`}>
                            SUSPENDED
                          </span>
                        </td>
                        <td className="py-3 text-right font-mono text-zinc-500">2026-06-23 10:42</td>
                      </tr>
                      <tr className={darkMode ? "hover:bg-white/[0.01]" : "hover:bg-zinc-50/50"}>
                        <td className="py-3 font-bold">Update Global Settings</td>
                        <td>Commission Fee: {settings.commissionFee}%</td>
                        <td>Super Admin</td>
                        <td>
                          <span className={`px-2 py-0.5 rounded text-[9px] font-extrabold uppercase tracking-wider bg-blue-500/10 text-blue-500`}>
                            UPDATED
                          </span>
                        </td>
                        <td className="py-3 text-right font-mono text-zinc-500">2026-06-22 09:00</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>

            </div>
          )}

          {/* TAB 2: Approvals (Companies Awaiting Approval) */}
          {selectedTab === "approvals" && (
            <div className="space-y-6 animate-fadeIn">
              
              {pendingCompanies.length === 0 ? (
                <div className={`border rounded-2xl p-12 text-center transition-all ${
                  darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
                }`}>
                  <div className="w-12 h-12 bg-emerald-500/10 text-emerald-500 border border-emerald-500/25 rounded-full flex items-center justify-center mx-auto mb-4">
                    <CheckCircleIcon className="w-6 h-6" />
                  </div>
                  <h3 className={`text-base font-bold mt-4 ${darkMode ? "text-white" : "text-zinc-900"}`}>All registrations reviewed!</h3>
                  <p className={`text-xs mt-2 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>No companies are currently waiting for approval.</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 gap-6">
                  {pendingCompanies.map(company => (
                    <div key={company.id} className={`border rounded-2xl p-6 flex flex-col md:flex-row md:items-center justify-between gap-6 hover:border-amber-500/40 transition-all duration-300 ${
                      darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm shadow-zinc-200/50"
                    }`}>
                      
                      <div className="space-y-2">
                        <div className="flex items-center gap-3">
                          <h3 className={`text-base font-bold ${darkMode ? "text-white" : "text-zinc-950"}`}>{company.name}</h3>
                          <span className={`bg-amber-500/10 text-amber-500 text-[9px] font-extrabold px-2.5 py-0.5 rounded-full uppercase tracking-wider border border-amber-500/20`}>
                            Awaiting Approval
                          </span>
                        </div>
                        
                        <div className={`grid grid-cols-2 md:grid-cols-4 gap-x-6 gap-y-1 text-xs ${
                          darkMode ? "text-zinc-400" : "text-zinc-500"
                        }`}>
                          <div><span className="font-semibold text-zinc-400">Owner:</span> {company.owner}</div>
                          <div><span className="font-semibold text-zinc-400">Email:</span> {company.email}</div>
                          <div><span className="font-semibold text-zinc-400">Category:</span> {company.category}</div>
                          <div><span className="font-semibold text-zinc-400">Submitted:</span> {company.submittedAt}</div>
                        </div>

                        <div className={`text-xs p-3 rounded-lg border mt-3 ${
                          darkMode ? "text-zinc-300 bg-[#172033] border-[#1E2D47]" : "text-zinc-700 bg-zinc-50 border-zinc-200"
                        }`}>
                          <span className="font-bold text-amber-500 block mb-1">Settlement Details:</span>
                          Bank Name: <span className="font-semibold text-emerald-500">{company.bankName}</span> &middot; Account Number: <span className="font-mono text-emerald-500 font-semibold">{company.accountNumber}</span>
                        </div>
                      </div>

                      <div className="flex items-center gap-3 md:self-end">
                        <button
                          onClick={() => setActiveReviewCompany(company)}
                          className={`px-4 py-2.5 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                            darkMode ? "bg-[#1E2D47] text-white hover:bg-[#263450]" : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200 border border-zinc-200 shadow-sm"
                          }`}
                        >
                          Review Details
                        </button>
                        <button
                          onClick={() => handleApprove(company.id)}
                          className="px-4 py-2.5 rounded-xl bg-gradient-to-br from-emerald-400 to-emerald-600 text-zinc-950 hover:opacity-95 text-xs font-bold shadow-md shadow-emerald-500/10 transition-all cursor-pointer"
                        >
                          Approve
                        </button>
                      </div>

                    </div>
                  ))}
                </div>
              )}

              {/* Review Details Overlay Modal */}
              {activeReviewCompany && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4">
                  <div className={`border w-full max-w-lg rounded-2xl overflow-hidden shadow-2xl ${
                    darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200"
                  }`}>
                    <div className={`h-16 border-b flex items-center justify-between px-6 ${
                      darkMode ? "bg-[#182235] border-[#1E2D47]" : "bg-zinc-50 border-zinc-200"
                    }`}>
                      <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Merchant Registration Application</h3>
                      <button 
                        onClick={() => setActiveReviewCompany(null)}
                        className={`text-xs hover:opacity-80 font-bold p-1 cursor-pointer ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}
                      >
                        ✕
                      </button>
                    </div>

                    <div className="p-6 space-y-4 text-xs">
                      <div>
                        <span className={`text-[10px] uppercase font-bold tracking-wider ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Business Name</span>
                        <div className={`text-base font-bold mt-1 ${darkMode ? "text-white" : "text-zinc-900"}`}>{activeReviewCompany.name}</div>
                      </div>

                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <span className={`text-[10px] uppercase font-bold tracking-wider ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Owner Name</span>
                          <div className={`font-semibold mt-0.5 ${darkMode ? "text-white" : "text-zinc-800"}`}>{activeReviewCompany.owner}</div>
                        </div>
                        <div>
                          <span className={`text-[10px] uppercase font-bold tracking-wider ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Business Category</span>
                          <div className={`font-semibold mt-0.5 ${darkMode ? "text-white" : "text-zinc-800"}`}>{activeReviewCompany.category}</div>
                        </div>
                      </div>

                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <span className={`text-[10px] uppercase font-bold tracking-wider ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Email Address</span>
                          <div className={`font-semibold mt-0.5 ${darkMode ? "text-white" : "text-zinc-800"}`}>{activeReviewCompany.email}</div>
                        </div>
                        <div>
                          <span className={`text-[10px] uppercase font-bold tracking-wider ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Phone Contact</span>
                          <div className={`font-semibold mt-0.5 ${darkMode ? "text-white" : "text-zinc-800"}`}>{activeReviewCompany.phone}</div>
                        </div>
                      </div>

                      <div className={`border rounded-xl p-4 space-y-2 ${
                        darkMode ? "bg-[#182235] border-[#1E2D47]" : "bg-zinc-50 border-zinc-200"
                      }`}>
                        <span className="text-[10px] text-amber-500 uppercase font-extrabold tracking-wider block">Settlement Bank Credentials</span>
                        <div>Bank / Mobile Wallet: <span className={`font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>{activeReviewCompany.bankName}</span></div>
                        <div>Settlement Account Number: <span className={`font-mono font-bold tracking-wider ${darkMode ? "text-white" : "text-zinc-900"}`}>{activeReviewCompany.accountNumber}</span></div>
                      </div>

                      <div>
                        <span className={`text-[10px] uppercase font-bold tracking-wider ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>Business Notes</span>
                        <p className={`mt-1 leading-relaxed ${darkMode ? "text-zinc-300" : "text-zinc-600"}`}>{activeReviewCompany.notes}</p>
                      </div>

                      <div className={`pt-4 border-t flex items-center justify-end gap-3 ${
                        darkMode ? "border-[#1E2D47]" : "border-zinc-200"
                      }`}>
                        <button
                          onClick={() => handleReject(activeReviewCompany.id)}
                          className="px-4 py-2.5 rounded-xl bg-rose-500/10 text-rose-500 border border-rose-500/20 hover:bg-rose-500/20 font-bold cursor-pointer"
                        >
                          Reject Request
                        </button>
                        <button
                          onClick={() => handleApprove(activeReviewCompany.id)}
                          className="px-4 py-2.5 rounded-xl bg-gradient-to-br from-emerald-400 to-emerald-600 text-zinc-950 hover:opacity-90 font-bold cursor-pointer"
                        >
                          Approve and Onboard
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              )}

            </div>
          )}

          {/* TAB 3: Active Companies (Approve / Suspend Ledger) */}
          {selectedTab === "active" && (
            <div className="space-y-6 animate-fadeIn">
              
              {/* Toolbar */}
              <div className={`border p-4 rounded-xl flex flex-col md:flex-row md:items-center justify-between gap-4 transition-all ${
                darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
              }`}>
                <div className="relative w-full md:max-w-xs">
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search by company, owner, or email..."
                    className={`w-full text-xs placeholder-zinc-500 px-4 py-2.5 pl-9 rounded-lg focus:outline-none border focus:border-emerald-500 ${
                      darkMode 
                        ? "bg-[#080E1A] border-[#1E2D47] text-white" 
                        : "bg-zinc-50 border-zinc-200 text-zinc-900 shadow-inner"
                    }`}
                  />
                  <div className="absolute left-3 top-3 text-zinc-500">
                    <SearchIcon className="w-4 h-4" />
                  </div>
                </div>
                <div className={`text-xs font-semibold ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
                  Showing <span className="text-emerald-500 font-extrabold">{filteredActiveCompanies.length}</span> of {approvedCompanies.length} approved companies
                </div>
              </div>

              {/* Table Ledger */}
              <div className={`border rounded-2xl overflow-hidden transition-all ${
                darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
              }`}>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead>
                      <tr className={`border-b text-zinc-400 font-bold uppercase tracking-wider ${
                        darkMode ? "border-[#1E2D47]" : "border-zinc-200"
                      }`}>
                        <th className="p-4">Company Name</th>
                        <th className="p-4">Owner Info</th>
                        <th className="p-4">Settlement Destination</th>
                        <th className="p-4">Processed Volume</th>
                        <th className="p-4">Integration State</th>
                        <th className="p-4 text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className={`divide-y font-medium ${
                      darkMode ? "divide-[#1E2D47]/40 text-zinc-300" : "divide-zinc-100 text-zinc-700"
                    }`}>
                      {companies.filter(c => c.status !== "PENDING" && c.status !== "REJECTED").map(company => (
                        <tr key={company.id} className={darkMode ? "hover:bg-white/[0.01]" : "hover:bg-zinc-50/50"}>
                          <td className="p-4">
                            <div className={`font-bold text-sm ${darkMode ? "text-white" : "text-zinc-900"}`}>{company.name}</div>
                            <div className={`text-[10px] font-bold uppercase tracking-wider ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{company.category}</div>
                          </td>
                          <td className="p-4">
                            <div>{company.owner}</div>
                            <div className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{company.email}</div>
                          </td>
                          <td className="p-4">
                            <div>{company.bankName}</div>
                            <div className={`text-[10px] font-mono ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{company.accountNumber}</div>
                          </td>
                          <td className={`p-4 font-mono font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>
                            {company.volume.toLocaleString()} ETB
                          </td>
                          <td className="p-4">
                            <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider border ${
                              company.status === "APPROVED" 
                                ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
                                : "bg-rose-500/10 text-rose-500 border-rose-500/20"
                            }`}>
                              {company.status === "APPROVED" ? "Active" : "Suspended"}
                            </span>
                          </td>
                          <td className="p-4 text-right">
                            <button
                              onClick={() => handleToggleSuspend(company.id)}
                              className={`px-3 py-1.5 rounded-lg font-bold text-[10px] tracking-wide transition-all cursor-pointer border ${
                                company.status === "APPROVED"
                                  ? "bg-rose-500/10 text-rose-500 border-rose-500/20 hover:bg-rose-500/20"
                                  : "bg-emerald-500/10 text-emerald-500 border border-emerald-500/20 hover:bg-emerald-500/20"
                              }`}
                            >
                              {company.status === "APPROVED" ? "Suspend Access" : "Activate Access"}
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

            </div>
          )}

          {/* TAB 4: Platform Settings */}
          {selectedTab === "settings" && (
            <div className="max-w-xl animate-fadeIn">
              <div className={`border rounded-2xl p-6 space-y-6 transition-all ${
                darkMode ? "bg-[#0F1626] border-[#1E2D47]" : "bg-white border-zinc-200 shadow-sm"
              }`}>
                
                <h3 className={`text-sm font-bold border-b pb-4 ${
                  darkMode ? "text-white border-[#1E2D47]" : "text-zinc-900 border-zinc-200"
                }`}>Global Fees & Matching Parameters</h3>
                
                <div className="space-y-4">
                  
                  <div>
                    <label className={`text-xs font-bold block mb-2 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>
                      Default Transaction Commission Fee (%)
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={settings.commissionFee}
                        onChange={(e) => setSettings({ ...settings, commissionFee: e.target.value })}
                        className={`w-full text-xs font-bold px-4 py-3 rounded-xl border focus:outline-none focus:border-emerald-500 outline-none ${
                          darkMode ? "bg-[#080E1A] border-[#1E2D47] text-white" : "bg-zinc-50 border-zinc-200 text-zinc-900 shadow-inner"
                        }`}
                      />
                      <span className="absolute right-4 top-3 text-zinc-400 font-bold">%</span>
                    </div>
                    <p className={`text-[10px] mt-1.5 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                      Platform fee charged automatically per verified transaction split.
                    </p>
                  </div>

                  <div>
                    <label className={`text-xs font-bold block mb-2 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>
                      Minimum Settlement Payout (ETB)
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={settings.minPayout}
                        onChange={(e) => setSettings({ ...settings, minPayout: e.target.value })}
                        className={`w-full text-xs font-bold px-4 py-3 rounded-xl border focus:outline-none focus:border-emerald-500 outline-none ${
                          darkMode ? "bg-[#080E1A] border-[#1E2D47] text-white" : "bg-zinc-50 border-zinc-200 text-zinc-900 shadow-inner"
                        }`}
                      />
                      <span className="absolute right-4 top-3 text-zinc-400 font-bold">ETB</span>
                    </div>
                    <p className={`text-[10px] mt-1.5 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                      Threshold amount required to release auto bank settlements.
                    </p>
                  </div>

                  <div>
                    <label className={`text-xs font-bold block mb-2 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>
                      Receipt OCR Verification Threshold (%)
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={settings.ocrConfidence}
                        onChange={(e) => setSettings({ ...settings, ocrConfidence: e.target.value })}
                        className={`w-full text-xs font-bold px-4 py-3 rounded-xl border focus:outline-none focus:border-emerald-500 outline-none ${
                          darkMode ? "bg-[#080E1A] border-[#1E2D47] text-white" : "bg-zinc-50 border-zinc-200 text-zinc-900 shadow-inner"
                        }`}
                      />
                      <span className="absolute right-4 top-3 text-zinc-400 font-bold">%</span>
                    </div>
                    <p className={`text-[10px] mt-1.5 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                      Matching score required to automatically verify scanned image payments.
                    </p>
                  </div>

                  <div className={`flex items-center justify-between p-4 border rounded-xl transition-all ${
                    darkMode ? "bg-[#182235] border-[#1E2D47]" : "bg-zinc-50 border-zinc-200 shadow-sm"
                  }`}>
                    <div>
                      <div className={`text-xs font-bold ${darkMode ? "text-white" : "text-zinc-950"}`}>Auto-Verify matching codes</div>
                      <p className={`text-[10px] mt-0.5 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Let verified OCR references immediately update status.</p>
                    </div>
                    <input
                      type="checkbox"
                      checked={settings.autoVerify}
                      onChange={(e) => setSettings({ ...settings, autoVerify: e.target.checked })}
                      className="w-5 h-5 accent-emerald-500 rounded cursor-pointer"
                    />
                  </div>

                </div>

                <div className={`pt-4 border-t ${darkMode ? "border-[#1E2D47]" : "border-zinc-200"}`}>
                  <button
                    onClick={() => showToast("System parameters updated and applied across nodes.", "success")}
                    className="w-full py-3.5 bg-gradient-to-br from-emerald-400 to-emerald-600 text-[#080E1A] font-bold rounded-xl shadow-lg shadow-emerald-500/10 hover:opacity-95 cursor-pointer text-xs"
                  >
                    <div className="flex items-center justify-center gap-1.5">
                      <SaveIcon className="w-4 h-4 text-zinc-950" />
                      <span>Save Platform Rules</span>
                    </div>
                  </button>
                </div>

              </div>
            </div>
          )}

        </div>

      </main>

    </div>
  );
}
