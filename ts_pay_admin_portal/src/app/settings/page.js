"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { CheckCircleIcon, SettingsIcon } from "@/components/Icons";
import DashboardLayout from "../dashboard-layout";

const defaultSettings = { commissionFee: "1.0", minPayout: "5,000", ocrConfidence: "85", autoVerify: true };

export default function SettingsPage() {
  const [darkMode, setDarkMode] = useState(true);
  const [settings, setSettings] = useState(defaultSettings);
  const [toast, setToast] = useState({ message: "", type: "info" });
  const [saving, setSaving] = useState(false);
  const [dbReady, setDbReady] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem("adminDarkMode");
    if (stored !== null) setDarkMode(JSON.parse(stored));
    loadSettings();
  }, []);

  useEffect(() => { localStorage.setItem("adminDarkMode", JSON.stringify(darkMode)); }, [darkMode]);

  const showToast = (msg, type = "success") => {
    setToast({ message: msg, type });
    setTimeout(() => setToast({ message: "", type: "info" }), 4000);
  };

  const loadSettings = async () => {
    const { data, error } = await supabase.from("platform_settings").select("*").limit(1).maybeSingle();
    if (!error && data) {
      setSettings({
        commissionFee: String(data.commission_fee ?? "1.0"),
        minPayout: String(data.min_payout ?? "5,000"),
        ocrConfidence: String(data.ocr_confidence ?? "85"),
        autoVerify: data.auto_verify ?? true,
      });
      setDbReady(true);
    } else {
      const saved = localStorage.getItem("platformSettings");
      if (saved) setSettings(JSON.parse(saved));
      setDbReady(false);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      if (dbReady) {
        const existing = await supabase.from("platform_settings").select("id").limit(1).maybeSingle();
        const payload = {
          commission_fee: parseFloat(settings.commissionFee) || 1.0,
          min_payout: parseFloat(settings.minPayout.replace(/,/g, "")) || 5000,
          ocr_confidence: parseFloat(settings.ocrConfidence) || 85,
          auto_verify: settings.autoVerify,
        };
        if (existing.data?.id) await supabase.from("platform_settings").update(payload).eq("id", existing.data.id);
        else await supabase.from("platform_settings").insert(payload);
      }
      localStorage.setItem("platformSettings", JSON.stringify(settings));
      showToast("System parameters updated and applied across nodes.", "success");
    } catch (err) {
      localStorage.setItem("platformSettings", JSON.stringify(settings));
      showToast("Saved locally. Run migration to enable database sync.", "info");
    } finally { setSaving(false); }
  };

  return (
    <DashboardLayout darkMode={darkMode} setDarkMode={setDarkMode}>
      <div className="space-y-6 animate-scaleIn">
        <div>
          <h1 className={`text-xl sm:text-2xl font-bold tracking-tight ${darkMode ? "text-white" : "text-zinc-900"}`}>
            Platform Settings
          </h1>
          <p className={`text-xs mt-1 ${darkMode ? "text-zinc-500" : "text-zinc-500"}`}>
            Global fees, rules, and matching parameters
          </p>
        </div>

        {toast.message && (
          <div className={`flex items-center gap-3 border px-5 py-4 rounded-xl animate-scaleIn ${
            toast.type === "success" ? "bg-emerald-500/10 border-emerald-500/20 text-emerald-400" :
            toast.type === "error" ? "bg-rose-500/10 border-rose-500/20 text-rose-400" :
            "bg-amber-500/10 border-amber-500/20 text-amber-400"
          }`}>
            <CheckCircleIcon className="w-5 h-5 flex-shrink-0" />
            <span className="text-sm font-semibold">{toast.message}</span>
          </div>
        )}

        <div className="max-w-2xl">
          <div className={`relative overflow-hidden rounded-2xl p-6 sm:p-8 border transition-all ${
            darkMode ? "bg-[#0F1626]/80 backdrop-blur-xl border-white/[0.06]" : "bg-white/80 backdrop-blur-xl border-black/5 shadow-sm"
          }`}>
            <div className={`absolute top-0 right-0 w-48 h-48 rounded-full blur-3xl pointer-events-none ${darkMode ? "bg-emerald-500/5" : "bg-emerald-500/3"}`} />

            <div className={`relative flex items-center gap-3 mb-6 pb-5 border-b ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
              <div className={`w-9 h-9 rounded-lg flex items-center justify-center ${
                darkMode ? "bg-emerald-500/10 text-emerald-400" : "bg-emerald-100 text-emerald-600"
              }`}>
                <SettingsIcon className="w-5 h-5" />
              </div>
              <div>
                <h3 className={`text-sm font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Global Fees & Parameters</h3>
                <p className={`text-[10px] ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                  Configure platform-wide rules
                </p>
              </div>
            </div>

            <div className="relative space-y-5">
              <SettingField
                darkMode={darkMode}
                label="Default Transaction Commission Fee"
                value={settings.commissionFee}
                onChange={(v) => setSettings({ ...settings, commissionFee: v })}
                suffix="%"
                description="Platform fee charged automatically per verified transaction split."
              />
              <SettingField
                darkMode={darkMode}
                label="Minimum Settlement Payout"
                value={settings.minPayout}
                onChange={(v) => setSettings({ ...settings, minPayout: v })}
                suffix="ETB"
                description="Threshold amount required to release auto bank settlements."
              />
              <SettingField
                darkMode={darkMode}
                label="Receipt OCR Verification Threshold"
                value={settings.ocrConfidence}
                onChange={(v) => setSettings({ ...settings, ocrConfidence: v })}
                suffix="%"
                description="Matching score required to automatically verify scanned image payments."
              />

              <div className={`flex items-center justify-between p-4 rounded-xl border transition-all ${
                darkMode ? "bg-[#182235] border-white/[0.06]" : "bg-zinc-50 border-black/5"
              }`}>
                <div>
                  <div className={`text-xs font-bold ${darkMode ? "text-white" : "text-zinc-900"}`}>Auto-Verify matching codes</div>
                  <p className={`text-[10px] mt-0.5 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>
                    Let verified OCR references immediately update status.
                  </p>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={settings.autoVerify}
                    onChange={(e) => setSettings({ ...settings, autoVerify: e.target.checked })}
                    className="sr-only peer"
                  />
                  <div className={`w-10 h-5 rounded-full peer peer-checked:after:translate-x-5 after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all ${
                    darkMode ? "bg-white/10 peer-checked:bg-emerald-500" : "bg-zinc-200 peer-checked:bg-emerald-500"
                  }`} />
                </label>
              </div>
            </div>

            <div className={`relative pt-5 mt-5 border-t ${darkMode ? "border-white/[0.06]" : "border-black/5"}`}>
              <button
                onClick={handleSave}
                disabled={saving}
                className="w-full py-3.5 bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 font-bold rounded-xl shadow-lg shadow-emerald-500/20 hover:from-emerald-400 hover:to-emerald-500 disabled:opacity-50 transition-all cursor-pointer text-xs"
              >
                {saving ? (
                  <span className="flex items-center justify-center gap-2">
                    <span className="w-4 h-4 border-2 border-zinc-950/30 border-t-zinc-950 rounded-full animate-spin" />
                    Saving...
                  </span>
                ) : "Save Platform Rules"}
              </button>
            </div>
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
}

function SettingField({ darkMode, label, value, onChange, suffix, description }) {
  return (
    <div>
      <label className={`text-xs font-bold block mb-2 ${darkMode ? "text-zinc-400" : "text-zinc-600"}`}>{label}</label>
      <div className="relative">
        <input
          type="text"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className={`w-full text-xs font-bold px-4 py-3 rounded-xl border outline-none transition-all ${
            darkMode ? "bg-[#080E1A] border-white/10 text-white focus:border-emerald-500/50 focus:ring-1 focus:ring-emerald-500/20" : "bg-zinc-50 border-black/10 text-zinc-900 focus:border-emerald-500/50"
          }`}
        />
        <span className="absolute right-4 top-1/2 -translate-y-1/2 text-zinc-400 font-bold text-xs">{suffix}</span>
      </div>
      <p className={`text-[10px] mt-1.5 ${darkMode ? "text-zinc-500" : "text-zinc-400"}`}>{description}</p>
    </div>
  );
}
