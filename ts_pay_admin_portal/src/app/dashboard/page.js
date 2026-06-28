"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell
} from "recharts";
import { CheckCircleIcon, XCircleIcon } from "@/components/Icons";
import DashboardLayout from "../dashboard-layout";

const COLORS = ["#10b981", "#f59e0b", "#ef4444"];

export default function DashboardPage() {
  const [metrics, setMetrics] = useState({
    totalAmount: 0, platformRevenue: 0, totalTransactions: 0,
    pendingCount: 0, verifiedCount: 0, failedCount: 0, userCount: 0, merchantCount: 0,
  });
  const [weeklyData, setWeeklyData] = useState([]);
  const [bankDistribution, setBankDistribution] = useState([]);
  const [recentActivity, setRecentActivity] = useState([]);
  const [loading, setLoading] = useState(true);
  const [darkMode, setDarkMode] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem("adminDarkMode");
    if (stored !== null) setDarkMode(JSON.parse(stored));
  }, []);

  useEffect(() => { localStorage.setItem("adminDarkMode", JSON.stringify(darkMode)); }, [darkMode]);

  useEffect(() => { loadData(); }, []);

  const loadData = async () => {
    try {
      const [txResult, profileResult] = await Promise.all([
        supabase.from("transactions").select("*"),
        supabase.from("profiles").select("*", { count: "exact", head: true }),
      ]);
      const txns = txResult.data || [];
      const totalAmount = txns.reduce((s, t) => s + (Number(t.amount) || 0), 0);
      const verifiedCount = txns.filter((t) => t.status === "VERIFIED").length;
      const failedCount = txns.filter((t) => t.status === "FAILED").length;
      const pendingCount = txns.filter((t) => t.status === "PENDING").length;

      setMetrics({
        totalAmount, platformRevenue: totalAmount * 0.01,
        totalTransactions: txns.length, pendingCount,
        verifiedCount, failedCount,
        userCount: profileResult.count || 0,
        merchantCount: new Set(txns.map((t) => t.verified_by).filter(Boolean)).size,
      });

      const days = [];
      for (let i = 6; i >= 0; i--) {
        const d = new Date(); d.setDate(d.getDate() - i);
        const dayStr = d.toISOString().slice(0, 10);
        const dayTxns = txns.filter((t) => t.created_at?.startsWith(dayStr));
        days.push({
          name: d.toLocaleDateString("en-US", { weekday: "short" }),
          total: dayTxns.reduce((s, t) => s + (Number(t.amount) || 0), 0),
          count: dayTxns.length,
        });
      }
      setWeeklyData(days);

      const bankMap = {};
      txns.forEach((t) => { bankMap[t.bank_name || "Other"] = (bankMap[t.bank_name || "Other"] || 0) + (Number(t.amount) || 0); });
      const total = Object.values(bankMap).reduce((s, v) => s + v, 0) || 1;
      setBankDistribution(Object.entries(bankMap).map(([name, value]) => ({ name, value: (value / total) * 100, amount: value })));

      setRecentActivity(txns.sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).slice(0, 8));
    } catch (err) { console.error("Failed to load dashboard data:", err); }
    finally { setLoading(false); }
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
            <span className="text-xs font-medium text-zinc-500">Loading dashboard...</span>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  const successRate = metrics.totalTransactions ? ((metrics.verifiedCount / metrics.totalTransactions) * 100).toFixed(1) : "0";

  return (
    <DashboardLayout darkMode={darkMode} setDarkMode={setDarkMode}>
      <div className="space-y-6 sm:space-y-8 animate-scaleIn">
        <div className="flex items-center justify-between">
          <div>
            <h1 className={`text-xl sm:text-2xl font-bold tracking-tight ${darkMode ? "text-white" : "text-zinc-900"}`}>
              Dashboard
            </h1>
            <p className={`text-xs mt-1 ${darkMode ? "text-zinc-500" : "text-zinc-500"}`}>
              Real-time settlement overview
            </p>
          </div>
        </div>

        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-5">
          <MetricCard darkMode={darkMode}           title="Processed Total" value={`${(metrics.totalAmount / 1000).toFixed(0)}K`} subtitle="ETB" icon={WalletIcon} />
          <MetricCard darkMode={darkMode} title="Platform Revenue" value={metrics.platformRevenue.toFixed(0)} subtitle="ETB (1% fee)" icon={RevenueIcon} />
          <MetricCard darkMode={darkMode} title="Transactions" value={metrics.totalTransactions} subtitle={`${metrics.verifiedCount} verified`} icon={ActivityIcon} />
          <MetricCard darkMode={darkMode} title="Pending" value={metrics.pendingCount} subtitle="awaiting review" icon={PendingIcon} />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
          <div className={`relative overflow-hidden rounded-2xl p-5 border transition-all lg:col-span-2 ${
            darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
          }`}>
            <div className={`absolute top-0 right-0 w-48 h-48 rounded-full blur-3xl pointer-events-none ${darkMode ? "bg-emerald-500/5" : "bg-emerald-500/3"}`} />
            <h3 className={`relative text-xs font-bold uppercase tracking-wider mb-5 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
              7-Day Total Trend
            </h3>
            <ResponsiveContainer width="100%" height={240}>
              <AreaChart data={weeklyData}>
                <defs><linearGradient id="totalGrad" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#10b981" stopOpacity={0.25} /><stop offset="100%" stopColor="#10b981" stopOpacity={0} /></linearGradient></defs>
                <CartesianGrid strokeDasharray="3 3" stroke={darkMode ? "#1E2D47" : "#E4E4E7"} />
                <XAxis dataKey="name" tick={{ fontSize: 10, fill: darkMode ? "#71717a" : "#a1a1aa" }} />
                <YAxis tick={{ fontSize: 10, fill: darkMode ? "#71717a" : "#a1a1aa" }} />
                <Tooltip contentStyle={{ backgroundColor: darkMode ? "#0F1626" : "#fff", border: `1px solid ${darkMode ? "#1E2D47" : "#E4E4E7"}`, borderRadius: 8, fontSize: 12 }} />
                <Area type="monotone" dataKey="total" stroke="#10b981" fill="url(#totalGrad)" strokeWidth={2.5} />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          <div className={`relative overflow-hidden rounded-2xl p-5 border transition-all ${
            darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
          }`}>
            <div className={`absolute top-0 right-0 w-36 h-36 rounded-full blur-3xl pointer-events-none ${darkMode ? "bg-emerald-500/5" : "bg-emerald-500/3"}`} />
            <h3 className={`relative text-xs font-bold uppercase tracking-wider mb-5 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>
              Wallet Distribution
            </h3>
            <div className="relative space-y-3.5">
              {bankDistribution.slice(0, 5).map((bank) => (
                <div key={bank.name}>
                  <div className="flex justify-between text-[11px] font-semibold mb-1.5">
                    <span className={darkMode ? "text-zinc-200" : "text-zinc-700"}>{bank.name}</span>
                    <span className="font-mono text-zinc-400">{bank.value.toFixed(0)}%</span>
                  </div>
                  <div className={`w-full h-2 rounded-full overflow-hidden ${darkMode ? "bg-white/5" : "bg-zinc-100"}`}>
                    <div className="h-full bg-gradient-to-r from-emerald-400 to-emerald-600 rounded-full transition-all duration-700" style={{ width: `${bank.value}%` }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
          <div className={`relative overflow-hidden rounded-2xl p-5 border transition-all ${
            darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
          }`}>
            <h3 className={`text-xs font-bold uppercase tracking-wider mb-3 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Verification Status</h3>
            <div className="flex items-center justify-center h-44">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={[
                    { name: "Verified", value: metrics.verifiedCount || 1 },
                    { name: "Pending", value: metrics.pendingCount || 0 },
                    { name: "Failed", value: metrics.failedCount || 0 },
                  ]} cx="50%" cy="50%" innerRadius={50} outerRadius={70} paddingAngle={3} dataKey="value">
                    {[0, 1, 2].map((i) => <Cell key={i} fill={COLORS[i]} />)}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="flex justify-center gap-4 text-[10px] font-semibold mt-2">
              {["Verified", "Pending", "Failed"].map((label, i) => (
                <span key={label} className="flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full" style={{ backgroundColor: COLORS[i] }} />
                  {label}
                </span>
              ))}
            </div>
          </div>

          <div className={`relative overflow-hidden rounded-2xl p-5 border transition-all ${
            darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
          }`}>
            <h3 className={`text-xs font-bold uppercase tracking-wider mb-3 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Daily Count</h3>
            <ResponsiveContainer width="100%" height={180}>
              <BarChart data={weeklyData}>
                <CartesianGrid strokeDasharray="3 3" stroke={darkMode ? "#1E2D47" : "#E4E4E7"} />
                <XAxis dataKey="name" tick={{ fontSize: 10, fill: darkMode ? "#71717a" : "#a1a1aa" }} />
                <Tooltip contentStyle={{ backgroundColor: darkMode ? "#0F1626" : "#fff", border: `1px solid ${darkMode ? "#1E2D47" : "#E4E4E7"}`, borderRadius: 8, fontSize: 12 }} />
                <Bar dataKey="count" fill="#10b981" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className={`relative overflow-hidden rounded-2xl p-5 border transition-all ${
            darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
          }`}>
            <h3 className={`text-xs font-bold uppercase tracking-wider mb-3 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Success Rate</h3>
            <div className="flex items-center justify-center h-36">
              <div className="relative">
                <svg className="w-36 h-36 -rotate-90" viewBox="0 0 36 36">
                  <circle cx="18" cy="18" r="15.915" fill="none" stroke={darkMode ? "#1E2D47" : "#F4F4F5"} strokeWidth="3" />
                  <circle cx="18" cy="18" r="15.915" fill="none" stroke="#10b981" strokeWidth="3.2" strokeDasharray={`${successRate} ${100 - parseFloat(successRate)}`} />
                </svg>
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                  <span className={`text-xl font-extrabold font-mono ${darkMode ? "text-white" : "text-zinc-900"}`}>{successRate}%</span>
                  <span className="text-[9px] font-bold uppercase tracking-wider text-zinc-500">Success</span>
                </div>
              </div>
            </div>
            <div className="text-center text-[10px] text-zinc-500 font-mono">
              {metrics.verifiedCount} verified / {metrics.totalTransactions} total
            </div>
          </div>
        </div>

        <div className={`relative overflow-hidden rounded-2xl border transition-all ${
          darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
        }`}>
          <div className="p-5">
            <h3 className={`text-xs font-bold uppercase tracking-wider ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>Recent Transactions</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className={`border-t text-zinc-400 font-bold uppercase tracking-wider ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
                  <th className="pb-3 px-5">Reference</th>
                  <th className="pb-3 px-5">Bank</th>
                  <th className="pb-3 px-5">Amount</th>
                  <th className="pb-3 px-5">Status</th>
                  <th className="pb-3 px-5 text-right">Date</th>
                </tr>
              </thead>
              <tbody className={`divide-y font-medium ${darkMode ? "divide-white/[0.04] text-zinc-300" : "divide-black/5 text-zinc-700"}`}>
                {recentActivity.map((tx) => (
                  <tr key={tx.id} className={`transition-colors ${darkMode ? "hover:bg-white/[0.02]" : "hover:bg-zinc-50"}`}>
                    <td className="py-3 px-5 font-bold">{tx.reference_code?.slice(0, 12)}...</td>
                    <td className="px-5">{tx.bank_name}</td>
                    <td className="px-5 font-mono">{Number(tx.amount).toLocaleString()} ETB</td>
                    <td className="px-5"><StatusBadge status={tx.status} /></td>
                    <td className="py-3 px-5 text-right font-mono text-zinc-500">{new Date(tx.created_at).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}

function MetricCard({ darkMode, title, value, subtitle, icon: Icon }) {
  return (
    <div className={`group relative overflow-hidden rounded-2xl p-4 sm:p-5 border transition-all duration-300 hover:scale-[1.02] ${
      darkMode
        ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06] hover:border-emerald-500/30"
        : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm hover:border-emerald-500/30 hover:shadow-md"
    }`}>
      <div className={`absolute top-0 right-0 w-24 h-24 rounded-full blur-3xl pointer-events-none transition-opacity group-hover:opacity-60 ${
        darkMode ? "bg-emerald-500/5" : "bg-emerald-500/3"
      }`} />
      <div className="relative flex items-start justify-between mb-3">
        <div className={`text-[10px] font-bold uppercase tracking-wider ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>{title}</div>
        {Icon && (
          <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${
            darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"
          }`}>
            <Icon className="w-4 h-4" />
          </div>
        )}
      </div>
      <div className="relative text-xl sm:text-2xl font-bold font-mono text-emerald-500">
        {value}
      </div>
      <div className={`relative text-[10px] font-semibold mt-1 ${darkMode ? "text-zinc-400" : "text-zinc-500"}`}>{subtitle}</div>
    </div>
  );
}

function StatusBadge({ status }) {
  const styles = {
    VERIFIED: "bg-emerald-500/10 text-emerald-400 border-emerald-500/20",
    PENDING: "bg-amber-500/10 text-amber-500 border-amber-500/20",
    FAILED: "bg-rose-500/10 text-rose-500 border-rose-500/20",
  };
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded text-[9px] font-extrabold uppercase tracking-wider border ${styles[status] || styles.PENDING}`}>
      {status === "VERIFIED" && <CheckCircleIcon className="w-3 h-3" />}
      {status === "FAILED" && <XCircleIcon className="w-3 h-3" />}
      {status}
    </span>
  );
}

function WalletIcon({ className }) { return <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5"><path strokeLinecap="round" strokeLinejoin="round" d="M21 12a2.25 2.25 0 00-2.25-2.25H15a3 3 0 11-6 0H5.25A2.25 2.25 0 003 12m18 0v6a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 18v-6m18 0V9M3 12V9m18 0a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 9m18 0V6a2.25 2.25 0 00-2.25-2.25H5.25A2.25 2.25 0 003 6v3" /></svg>; }
function RevenueIcon({ className }) { return <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5"><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>; }
function ActivityIcon({ className }) { return <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5"><path strokeLinecap="round" strokeLinejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5" /></svg>; }
function PendingIcon({ className }) { return <svg className={className} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="1.5"><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>; }
