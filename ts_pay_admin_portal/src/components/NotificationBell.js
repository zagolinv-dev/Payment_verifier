"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { createPortal } from "react-dom";
import { supabase } from "@/lib/supabase";
import { BellIcon, CheckCircleIcon, XCircleIcon, AlertTriangleIcon } from "./Icons";

export default function NotificationBell({ darkMode }) {
  const [notifications, setNotifications] = useState([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [mounted, setMounted] = useState(false);
  
  // Modal state
  const [resetModalOpen, setResetModalOpen] = useState(false);
  const [resetTargetEmail, setResetTargetEmail] = useState("");
  const [resetTargetName, setResetTargetName] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [isResetting, setIsResetting] = useState(false);
  const [resetSuccessPassword, setResetSuccessPassword] = useState("");
  const prevIdsRef = useRef(new Set());
  const notifiedIdsRef = useRef(new Set());
  const ref = useRef();
  const portalRef = useRef();

  useEffect(() => { setMounted(true); }, []);

  const requestNotifyPermission = useCallback(async () => {
    if (!("Notification" in window)) return false;
    if (Notification.permission === "granted") return true;
    if (Notification.permission === "denied") return false;
    const result = await Notification.requestPermission();
    return result === "granted";
  }, []);

  const showBrowserNotification = useCallback((title, body) => {
    if (!("Notification" in window) || Notification.permission !== "granted") return;
    try {
      const n = new Notification(title, {
        body,
        icon: "/favicon.ico",
        tag: "ts-verify-notification",
      });
      setTimeout(() => n.close(), 8000);
    } catch {}
  }, []);

  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, 30000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const handler = (e) => {
      if (!open) return;
      if (ref.current && ref.current.contains(e.target)) return;
      if (portalRef.current && portalRef.current.contains(e.target)) return;
      setOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  const handleOpenResetModal = (notification) => {
    const emailMatch = notification.message.match(/\(([^)]+)\)/);
    const email = emailMatch ? emailMatch[1] : "";
    
    const nameMatch = notification.message.match(/(?:Manager|Waiter)\s+([^(]+)\s+\(/);
    const name = nameMatch ? nameMatch[1].trim() : "";

    setResetTargetEmail(email);
    setResetTargetName(name);
    setNewPassword("");
    setResetSuccessPassword("");
    setResetModalOpen(true);
    setOpen(false);
  };

  const submitResetPassword = async () => {
    if (!newPassword || newPassword.length < 8) {
      alert("Password must be at least 8 characters.");
      return;
    }
    setIsResetting(true);
    try {
      const res = await supabase.functions.invoke("reset-user-password", {
        body: { email: resetTargetEmail, newPassword }
      });
      if (res.error) throw new Error(res.error.message || "Unknown error");
      setResetSuccessPassword(newPassword);
    } catch (err) {
      alert("Failed to reset password: " + err.message);
    }
    setIsResetting(false);
  };

  const copyNewPassword = () => {
    navigator.clipboard.writeText(resetSuccessPassword);
    alert("Password copied to clipboard!");
  };

  const fetchNotifications = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) return;

      const [dbNotesResult, profileResult, txResult] = await Promise.all([
        supabase
          .from("notifications")
          .select("*")
          .eq("user_id", session.user.id)
          .order("created_at", { ascending: false })
          .limit(10),
        supabase
          .from("profiles")
          .select("id, created_at, full_name")
          .eq("status", "PENDING")
          .eq("role", "ADMIN")
          .limit(5),
        supabase
          .from("transactions")
          .select("id, status, amount, created_at")
          .eq("status", "FAILED")
          .limit(5),
      ]);

      const computed = [];

      if (dbNotesResult.data) {
        dbNotesResult.data.forEach((n) => {
          computed.push(n);
        });
      }

      if (profileResult.data) {
        profileResult.data.forEach((m) => {
          computed.push({
            id: `approval-${m.id}`,
            type: "approval",
            title: "New Merchant Registration",
            message: `${m.full_name || "Someone"} registered as a merchant.`,
            is_read: false,
            created_at: m.created_at,
          });
        });
      }

      if (txResult.data) {
        txResult.data.forEach((t) => {
          computed.push({
            id: `failed-${t.id}`,
            type: "failed",
            title: "Failed Transaction",
            message: `${Number(t.amount).toLocaleString()} ETB transaction failed.`,
            is_read: false,
            created_at: t.created_at,
          });
        });
      }

      computed.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
      const sliced = computed.slice(0, 10);
      const newIds = new Set(sliced.map((n) => n.id));
      const prevIds = prevIdsRef.current;
      if (prevIds.size > 0) {
        sliced.forEach((n) => {
          if (!prevIds.has(n.id) && !notifiedIdsRef.current.has(n.id)) {
            notifiedIdsRef.current.add(n.id);
            showBrowserNotification(n.title, n.message);
          }
        });
      }
      prevIdsRef.current = newIds;
      setNotifications(sliced);
    } catch (err) {
      console.error("Failed to fetch notifications:", err);
    } finally {
      setLoading(false);
    }
  };

  const markAsRead = async (id) => {
    if (id.startsWith("approval-") || id.startsWith("failed-")) {
      setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, is_read: true } : n)));
      setOpen(false);
      return;
    }
    await supabase.from("notifications").update({ is_read: true }).eq("id", id);
    setNotifications((prev) => prev.map((n) => (n.id === id ? { ...n, is_read: true } : n)));
  };

  const markAllRead = async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;
    await supabase.from("notifications").update({ is_read: true }).eq("user_id", session.user.id);
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
  };

  const clearAll = async () => {
    if (!confirm("Delete all notifications?")) return;
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;
    const dbIds = notifications.filter((n) => !n.id.startsWith("approval-") && !n.id.startsWith("failed-")).map((n) => n.id);
    if (dbIds.length > 0) {
      await supabase.from("notifications").delete().in("id", dbIds);
    }
    notifiedIdsRef.current = new Set();
    prevIdsRef.current = new Set();
    setNotifications([]);
  };

  const unreadCount = notifications.filter((n) => !n.is_read).length;

  const typeStyles = {
    approval: { bg: darkMode ? "bg-emerald-500/10" : "bg-emerald-50", border: darkMode ? "border-emerald-500/20" : "border-emerald-200", icon: "text-emerald-400", Icon: CheckCircleIcon },
    failed: { bg: darkMode ? "bg-rose-500/10" : "bg-rose-50", border: darkMode ? "border-rose-500/20" : "border-rose-200", icon: "text-rose-400", Icon: XCircleIcon },
    info: { bg: darkMode ? "bg-amber-500/10" : "bg-amber-50", border: darkMode ? "border-amber-500/20" : "border-amber-200", icon: "text-amber-400", Icon: AlertTriangleIcon },
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => { setOpen(!open); requestNotifyPermission(); }}
        className={`relative p-2 sm:p-2.5 rounded-xl border transition-all cursor-pointer ${
          darkMode
            ? "bg-white/5 border-white/10 text-zinc-400 hover:text-white hover:bg-white/10"
            : "bg-black/5 border-black/10 text-zinc-600 hover:text-zinc-950 hover:bg-black/10"
        }`}
        title="Notifications"
      >
        <BellIcon className="w-4 h-4 sm:w-5 sm:h-5" />
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 w-4.5 h-4.5 flex items-center justify-center bg-rose-500 text-white text-[8px] font-extrabold rounded-full min-w-[18px] min-h-[18px] shadow-lg shadow-rose-500/30">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        )}
      </button>

      {mounted && open && createPortal(
        <div ref={portalRef} className={`fixed top-14 left-3 right-3 sm:top-16 sm:right-4 sm:left-auto sm:w-96 rounded-2xl border shadow-2xl overflow-hidden z-[100] transition-all animate-scaleIn ${
          darkMode ? "bg-[#0F1626] border-white/[0.06]" : "bg-white border-black/5"
        }`} style={{ maxHeight: "calc(100vh - 80px)" }}>
          <div className={`px-5 py-3.5 border-b flex items-center justify-between gap-2 ${
            darkMode ? "border-white/[0.06]" : "border-black/5"
          }`}>
            <h3 className={`text-xs font-bold uppercase tracking-wider ${darkMode ? "text-zinc-300" : "text-zinc-700"}`}>
              Notifications
            </h3>
            <div className="flex items-center gap-1.5">
              {notifications.some((n) => !n.is_read) && (
                <button
                  onClick={(e) => { e.stopPropagation(); markAllRead(); }}
                  className={`text-[10px] font-bold px-2 py-1 rounded-lg transition-all cursor-pointer ${
                    darkMode ? "bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20" : "bg-emerald-50 text-emerald-600 hover:bg-emerald-100"
                  }`}
                >
                  Mark all read
                </button>
              )}
              {notifications.length > 0 && (
                <button
                  onClick={(e) => { e.stopPropagation(); clearAll(); }}
                  className={`text-[10px] font-bold px-2 py-1 rounded-lg transition-all cursor-pointer ${
                    darkMode ? "bg-rose-500/10 text-rose-400 hover:bg-rose-500/20" : "bg-rose-50 text-rose-600 hover:bg-rose-100"
                  }`}
                >
                  Clear all
                </button>
              )}
              {unreadCount > 0 && (
                <span className={`text-[10px] font-extrabold px-2 py-0.5 rounded-full ${
                  darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-50 text-emerald-600"
                }`}>
                  {unreadCount} new
                </span>
              )}
            </div>
          </div>

          <div className="overflow-y-auto" style={{ maxHeight: "360px" }}>
            {loading ? (
              <div className="flex items-center justify-center py-10">
                <div className="flex gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "0ms" }} />
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "150ms" }} />
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "300ms" }} />
                </div>
              </div>
            ) : notifications.length === 0 ? (
              <div className="flex flex-col items-center py-10 px-5 text-center">
                <BellIcon className={`w-8 h-8 mb-3 ${darkMode ? "text-zinc-600" : "text-zinc-300"}`} />
                <p className={`text-xs font-semibold ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>All caught up!</p>
                <p className={`text-[10px] mt-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>No new notifications.</p>
              </div>
            ) : (
              notifications.map((n) => {
                const style = typeStyles[n.type] || typeStyles.info;
                return (
                  <button
                    key={n.id}
                    onClick={() => markAsRead(n.id)}
                    className={`w-full text-left px-5 py-3.5 border-b transition-all cursor-pointer ${
                      darkMode
                        ? `${n.is_read ? "" : "bg-white/[0.02]"} border-white/[0.04] hover:bg-white/[0.04]`
                        : `${n.is_read ? "" : "bg-zinc-50"} border-black/5 hover:bg-zinc-50`
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 border ${style.bg} ${style.border}`}>
                        <style.Icon className={`w-4 h-4 ${style.icon}`} />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className={`text-xs font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>{n.title}</div>
                        <p className={`text-[10px] mt-0.5 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>{n.message}</p>
                        <p className={`text-[9px] mt-1 font-mono ${darkMode ? "text-zinc-600" : "text-zinc-400"}`}>
                          {new Date(n.created_at).toLocaleString()}
                        </p>
                      </div>
                      {!n.is_read && (
                        <span className="w-2 h-2 rounded-full bg-emerald-500 flex-shrink-0 mt-1.5" />
                      )}
                    </div>
                    {n.title.includes("Password Reset Appeal") && (
                      <div className="mt-3">
                        <div
                          role="button"
                          tabIndex={0}
                          onClick={(e) => { e.stopPropagation(); handleOpenResetModal(n); }}
                          onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.stopPropagation(); handleOpenResetModal(n); } }}
                          className={`w-full py-2 rounded-lg text-xs font-bold transition-all cursor-pointer text-center select-none ${
                            darkMode ? "bg-amber-500/20 text-amber-400 hover:bg-amber-500/30" : "bg-amber-100 text-amber-700 hover:bg-amber-200"
                          }`}
                        >
                          Generate New Password
                        </div>
                      </div>
                    )}
                  </button>
                );
              })
            )}
          </div>
        </div>,
        document.body
      )}

      {mounted && resetModalOpen && createPortal(
        <div className="fixed inset-0 z-[1000] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-scaleIn">
          <div className={`relative w-full max-w-sm rounded-2xl overflow-hidden border shadow-2xl p-6 ${
            darkMode ? "bg-[#0F1626] border-white/[0.06]" : "bg-white border-black/5"
          }`}>
            <h3 className={`text-base font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Reset Password</h3>
            <p className={`text-xs mt-1 mb-4 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
              Set a new password for {resetTargetName || resetTargetEmail}.
            </p>

            {!resetSuccessPassword ? (
              <div className="space-y-4">
                <div>
                  <label className={`text-xs font-bold block mb-1.5 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>New Password</label>
                  <input 
                    type="text" 
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder="Min 8 characters"
                    className={`w-full px-4 py-2.5 rounded-xl border text-sm outline-none transition-all ${darkMode ? "bg-white/5 border-white/10 text-white focus:border-amber-500/50" : "bg-black/5 border-black/10 text-zinc-900 focus:border-amber-500/50"}`}
                  />
                </div>
                <div className="flex justify-end gap-2 pt-2">
                  <button 
                    onClick={() => setResetModalOpen(false)}
                    className={`px-4 py-2.5 rounded-xl text-xs font-bold cursor-pointer transition-all ${darkMode ? "bg-white/5 text-zinc-300 hover:bg-white/10" : "bg-zinc-100 text-zinc-700 hover:bg-zinc-200"}`}
                  >
                    Cancel
                  </button>
                  <button 
                    onClick={submitResetPassword}
                    disabled={isResetting}
                    className="px-4 py-2.5 rounded-xl bg-gradient-to-r from-amber-500 to-amber-600 text-zinc-950 font-bold text-xs shadow-lg shadow-amber-500/20 hover:from-amber-400 hover:to-amber-500 transition-all cursor-pointer disabled:opacity-50"
                  >
                    {isResetting ? "Resetting..." : "Set Password"}
                  </button>
                </div>
              </div>
            ) : (
              <div className="space-y-4">
                <div className={`p-4 rounded-xl flex items-center justify-between ${darkMode ? "bg-white/[0.03]" : "bg-zinc-50"}`}>
                  <div>
                    <div className={`text-[10px] font-semibold uppercase tracking-wider mb-1 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>New Password</div>
                    <div className={`text-sm font-mono font-bold ${darkMode ? "text-amber-400" : "text-amber-600"}`}>{resetSuccessPassword}</div>
                  </div>
                  <button
                    onClick={copyNewPassword}
                    className={`px-3 py-1.5 rounded-lg transition-colors cursor-pointer border font-bold text-[10px] uppercase tracking-wide flex-shrink-0 ${
                      darkMode 
                        ? "bg-white/5 border-white/10 text-zinc-400 hover:text-white hover:bg-white/10" 
                        : "bg-white border-zinc-200 text-zinc-600 hover:text-zinc-950 hover:bg-zinc-50"
                    }`}
                  >
                    Copy
                  </button>
                </div>
                <button 
                  onClick={() => setResetModalOpen(false)}
                  className="w-full py-2.5 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 font-bold text-xs shadow-lg shadow-emerald-500/20 hover:from-emerald-400 hover:to-emerald-500 transition-all cursor-pointer"
                >
                  Done
                </button>
              </div>
            )}
          </div>
        </div>,
        document.body
      )}
    </div>
  );
}
