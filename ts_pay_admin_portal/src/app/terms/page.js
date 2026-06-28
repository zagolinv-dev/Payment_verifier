"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

const DEFAULT_TERMS = `Terms of Service

Last Updated: June 2026

1. Acceptance of Terms

By accessing or using T's Verify ("the Platform"), you agree to be bound by these Terms of Service. If you do not agree, do not use the Platform.

2. Description of Service

T's Verify provides a payment verification and settlement platform for merchants and their customers. The Platform facilitates transaction verification, receipt matching via OCR, and automated bank settlements.

3. Merchant Responsibilities

3.1 You must provide accurate business information during registration.
3.2 You are responsible for all transactions processed under your account.
3.3 You must comply with all applicable Ethiopian laws and regulations.

4. Fee Structure

A platform commission fee is charged per verified transaction as configured in your account settings. Fees are non-refundable once a transaction has been verified.

5. Payment Settlement

Settlements are processed according to the configured minimum payout threshold. T's Verify reserves the right to hold settlements for review if suspicious activity is detected.

6. Prohibited Activities

You may not use the Platform for:
- Fraudulent or illegal transactions
- Money laundering
- Processing payments for prohibited goods or services
- Any activity that violates Ethiopian law

7. Limitation of Liability

T's Verify is not liable for any indirect, incidental, or consequential damages arising from your use of the Platform. Our total liability is limited to the fees paid by you in the 30 days preceding a claim.

8. Termination

We reserve the right to suspend or terminate access to the Platform for violation of these terms, with or without notice.

9. Changes to Terms

We may update these terms at any time. Continued use after changes constitutes acceptance of the new terms.

10. Governing Law

These terms are governed by the laws of the Federal Democratic Republic of Ethiopia.

11. Contact

For questions about these terms, contact support@tspay.com`;

export default function TermsPage() {
  const [darkMode, setDarkMode] = useState(() => typeof window !== "undefined" ? JSON.parse(localStorage.getItem("adminDarkMode") ?? "false") : false);
  const [content, setContent] = useState(DEFAULT_TERMS);

  useEffect(() => {
    const handler = (e) => setDarkMode(e.detail);
    window.addEventListener("darkmodechange", handler);
    loadContent();
    return () => window.removeEventListener("darkmodechange", handler);
  }, []);

  const loadContent = async () => {
    try {
      const { data, error } = await supabase.from("platform_settings").select("terms_content").limit(1).maybeSingle();
      if (!error && data?.terms_content) setContent(data.terms_content);
    } catch { /* use default */ }
  };

  const styles = {
    bg: darkMode ? "bg-[#080E1A]" : "bg-zinc-50",
    card: darkMode ? "bg-[#0F1626]/80 border-white/[0.06]" : "bg-white/80 border-black/5 shadow-sm",
    text: darkMode ? "text-zinc-300" : "text-zinc-700",
    heading: darkMode ? "text-white" : "text-zinc-900",
    subheading: darkMode ? "text-zinc-200" : "text-zinc-800",
    blur: darkMode ? "bg-emerald-500/5" : "bg-emerald-500/3",
    headerBorder: darkMode ? "border-white/[0.06]" : "border-black/5",
  };

  return (
    <div className={`min-h-screen ${styles.bg} font-sans transition-colors duration-500`}>
      <div className={`sticky top-0 z-10 border-b backdrop-blur-xl ${styles.headerBorder} ${darkMode ? "bg-[#0F1626]/80" : "bg-white/80"}`}>
        <div className="max-w-3xl mx-auto px-4 sm:px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img src="/logo.png" alt="T's Verify" className="w-7 h-7 object-contain" />
            <span className={`text-sm font-bold ${styles.heading}`}>T's Verify</span>
          </div>
          <div className="flex items-center gap-3">
            <Link
              href="/privacy_policy"
              className={`text-xs font-semibold transition-colors ${
                darkMode ? "text-zinc-400 hover:text-zinc-200" : "text-zinc-500 hover:text-zinc-800"
              }`}
            >
              Privacy Policy
            </Link>
            <Link
              href="/dashboard"
              className="px-3 py-1.5 rounded-lg bg-gradient-to-r from-emerald-500 to-emerald-600 text-zinc-950 font-bold text-[10px] transition-all hover:from-emerald-400 hover:to-emerald-500"
            >
              Dashboard
            </Link>
          </div>
        </div>
      </div>
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8 sm:py-10">
        <div className={`relative overflow-hidden rounded-2xl border transition-all ${styles.card}`}>
          <div className={`absolute top-0 right-0 w-48 h-48 rounded-full blur-3xl pointer-events-none ${styles.blur}`} />
          <div className="p-6 sm:p-10">
            <div className={`whitespace-pre-line text-sm leading-relaxed ${styles.text}`}>
              {content.split("\n\n").map((section, i) => {
                const lines = section.split("\n");
                const isHeading = lines[0] === lines[0].toUpperCase() && lines[0].length > 3;
                if (isHeading) {
                  return (
                    <div key={i} className="mb-6">
                      <h2 className={`text-lg font-bold mb-3 ${styles.heading}`}>{lines[0]}</h2>
                      {lines.slice(1).length > 0 && (
                        <div className="space-y-2">
                          {lines.slice(1).filter(Boolean).map((line, j) => {
                            const isSubheading = /^\d+\./.test(line);
                            if (isSubheading) return <h3 key={j} className={`font-bold mt-4 mb-1 ${styles.subheading}`}>{line}</h3>;
                            if (line.startsWith("- ")) return <li key={j} className="ml-4 list-disc">{line.slice(2)}</li>;
                            return <p key={j}>{line}</p>;
                          })}
                        </div>
                      )}
                    </div>
                  );
                }
                return <p key={i} className="mb-4">{section}</p>;
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
