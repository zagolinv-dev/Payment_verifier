"use client";

import { useState, useCallback } from "react";
import { CheckCircleIcon, XCircleIcon, AlertTriangleIcon } from "./Icons";

export function useToast() {
  const [toast, setToast] = useState({ message: "", type: "info" });

  const showToast = useCallback((message, type = "success") => {
    setToast({ message, type });
    setTimeout(() => {
      setToast({ message: "", type: "info" });
    }, 4000);
  }, []);

  return { toast, showToast };
}

export function Toast({ toast, darkMode }) {
  if (!toast.message) return null;

  return (
    <div className={`fixed bottom-6 right-6 z-50 flex items-center gap-3 border px-5 py-4 rounded-xl shadow-2xl animate-fadeIn ${
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
  );
}

function InfoIcon({ className }) {
  return (
    <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
  );
}
