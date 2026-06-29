"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

const DEFAULT_PRIVACY = `Privacy Policy

Last Updated: June 2026

1. Information We Collect

We collect the following information when you use T's Verify:

1.1 Account Information: Name, email address, phone number, and business details provided during registration.
1.2 Transaction Data: Payment amounts, bank account details, transaction references, and verification results.
1.3 Usage Data: Log data including IP address, browser type, and pages accessed.

2. How We Use Your Information

We use collected information to:
- Process and verify payments
- Detect and prevent fraud
- Communicate important updates about the Platform
- Comply with legal and regulatory obligations
- Improve and optimize Platform performance

3. Data Sharing

We do not sell your personal information. We may share data with:
- Banking partners to facilitate settlements
- Regulatory authorities as required by Ethiopian law
- Service providers who assist in Platform operations (under strict confidentiality agreements)

4. Data Security

We implement industry-standard security measures including:
- Encryption of data in transit and at rest
- Access controls and authentication requirements
- Regular security audits and monitoring
- Secure data storage with restricted access

5. Data Retention

We retain your data for as long as your account is active or as needed to provide services. Transaction records are retained for a minimum of 7 years to comply with financial regulations.

6. Your Rights

You have the right to:
- Access your personal data held by us
- Request correction of inaccurate data
- Request deletion of your data (subject to legal retention requirements)
- Withdraw consent for data processing where applicable

7. Cookies

The Platform uses essential cookies for authentication and security. We do not use tracking cookies for marketing purposes.

8. Changes to This Policy

We may update this Privacy Policy periodically. Material changes will be communicated via email or Platform notification.

9. Contact

For privacy-related inquiries, contact:
Email: privacy@tspay.com
Address: Addis Ababa, Ethiopia`;

export default function PrivacyPolicyPage() {
  const [darkMode, setDarkMode] = useState(() => typeof window !== "undefined" ? JSON.parse(localStorage.getItem("adminDarkMode") ?? "false") : false);
  const [content, setContent] = useState(DEFAULT_PRIVACY);

  useEffect(() => {
    const handler = (e) => setDarkMode(e.detail);
    window.addEventListener("darkmodechange", handler);
    loadContent();
    return () => window.removeEventListener("darkmodechange", handler);
  }, []);

  const loadContent = async () => {
    try {
      const { data, error } = await supabase.from("platform_settings").select("privacy_content").limit(1).maybeSingle();
      if (!error && data?.privacy_content) setContent(data.privacy_content);
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
              href="/terms"
              className={`text-xs font-semibold transition-colors ${
                darkMode ? "text-zinc-400 hover:text-zinc-200" : "text-zinc-500 hover:text-zinc-800"
              }`}
            >
              Terms of Service
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
                            const isSubheading = /^\d+\.\d+\s/.test(line);
                            if (isSubheading) return <h3 key={j} className={`font-bold mt-3 mb-1 ${styles.subheading}`}>{line}</h3>;
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
