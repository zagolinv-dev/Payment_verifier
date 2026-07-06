"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

const DEFAULT_TERMS = `TERMS OF SERVICE

Last Updated: July 2026

Please read these Terms of Service ("Terms", "Terms of Service") carefully before using the T's Verify mobile application and web platform (collectively, the "Service") operated by T's Verify ("us", "we", or "our").

Your access to and use of the Service is conditioned on your acceptance of and compliance with these Terms. These Terms apply to all visitors, users, merchants, and others who access or use the Service.

By accessing or using the Service you agree to be bound by these Terms. If you disagree with any part of the Terms, you may not access the Service.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Definitions

1.1 "Platform" refers to the T's Verify mobile application and web-based administrative portal.
1.2 "Merchant" refers to any business entity registered on the Platform to process and verify payments.
1.3 "Waitress" or "Agent" refers to an individual user authorized by a Merchant to initiate and verify transactions on behalf of that Merchant.
1.4 "User" refers to any individual or entity that accesses or uses the Platform, including Merchants, Waitresses, and administrators.
1.5 "Transaction" refers to any payment processed, verified, or settled through the Platform.
1.6 "OCR" refers to optical character recognition technology used to match receipts with transaction records.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

2. Account Registration and Eligibility

2.1 To use the Service, you must register for an account and provide accurate, current, and complete information as prompted by the registration form.
2.2 You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.
2.3 You must notify us immediately of any unauthorized use of your account or any other breach of security.
2.4 You must be at least 18 years of age to use the Service. By registering, you represent and warrant that you are at least 18 years old.
2.5 We reserve the right to refuse registration of, or suspend, any account at our sole discretion.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

3. Description of Service

3.1 T's Verify provides a payment verification and settlement platform that enables:
  - Transaction recording and verification
  - Receipt matching via OCR technology
  - Automated bank settlement processing
  - Real-time transaction monitoring and reporting
  - User and role management for merchants
3.2 The Service acts as a verification intermediary and does not directly process financial transactions between payers and merchants.
3.3 We reserve the right to modify, suspend, or discontinue any aspect of the Service at any time without prior notice.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

4. Merchant Responsibilities

4.1 Merchants must provide accurate and complete business information during registration, including legal business name, address, and banking details.
4.2 Merchants are responsible for all transactions processed under their account, including transactions initiated by authorized Waitresses or Agents.
4.3 Merchants must ensure that all Waitresses and Agents associated with their account comply with these Terms.
4.4 Merchants must maintain valid and current banking information for settlement processing.
4.5 Merchants must comply with all applicable laws and regulations of the Federal Democratic Republic of Ethiopia, including tax and financial reporting obligations.
4.6 Merchants are responsible for obtaining any necessary licenses, permits, or approvals required to operate their business.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

5. User Roles and Authorization

5.1 The Platform supports the following user roles:
  - Super Admin: Platform administrators with full system access.
  - Admin: Merchant account managers who can manage users, view reports, and configure settings.
  - Waitress/Agent: Authorized personnel who can initiate and verify transactions.
5.2 Each user role has specific permissions and access levels as defined by the Platform.
5.3 Account holders are responsible for the actions of all users associated with their account.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

6. Fees and Payment

6.1 The Platform charges a commission fee per verified transaction as configured in the Merchant's account settings.
6.2 All fees are non-refundable once a transaction has been processed and verified.
6.3 We reserve the right to modify our fee structure at any time. Changes will be communicated to Merchants via email or Platform notification at least 14 days in advance.
6.4 Merchants are responsible for any applicable taxes, duties, or levies imposed by regulatory authorities.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

7. Settlement Processing

7.1 Settlements are processed according to the configured minimum payout threshold and settlement schedule.
7.2 Settlement timelines may vary based on banking partner processing times and regulatory requirements.
7.3 We reserve the right to hold, delay, or reverse settlements if:
  - Suspicious or potentially fraudulent activity is detected.
  - Discrepancies are identified in transaction records.
  - Required verification or documentation is incomplete.
  - We are instructed to do so by regulatory authorities.
7.4 Disputed transactions will be investigated, and settlements may be withheld until the dispute is resolved.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

8. Prohibited Activities

8.1 You may not use the Service for any unlawful purpose or in violation of these Terms.
8.2 Prohibited activities include, but are not limited to:
  - Processing fraudulent or unauthorized transactions.
  - Money laundering or terrorist financing.
  - Processing payments for illegal goods or services.
  - Attempting to circumvent Platform security measures.
  - Interfering with or disrupting the integrity of the Service.
  - Reverse engineering, decompiling, or disassembling the Platform.
  - Using automated scripts, bots, or scrapers to access the Platform.
  - Impersonating any person or entity.
8.3 Violation of these prohibitions may result in immediate account termination and referral to law enforcement authorities.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

9. Intellectual Property Rights

9.1 The Service and its original content, features, and functionality are owned by T's Verify and are protected by international copyright, trademark, and other intellectual property laws.
9.2 You may not reproduce, distribute, modify, create derivative works from, or exploit any portion of the Service without our express written permission.
9.3 The T's Verify name, logo, and all related names, logos, product and service names, designs, and slogans are trademarks of T's Verify.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

10. Privacy and Data Protection

10.1 Your use of the Service is also governed by our Privacy Policy, which is incorporated into these Terms by reference.
10.2 We collect, process, and store personal and transaction data as described in our Privacy Policy.
10.3 We implement reasonable security measures to protect your data, but we cannot guarantee absolute security.
10.4 By using the Service, you consent to the collection and use of your data as described in our Privacy Policy.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

11. Limitation of Liability

11.1 To the maximum extent permitted by applicable law, T's Verify and its officers, directors, employees, and agents shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or relating to your use of the Service.
11.2 This includes, but is not limited to, damages for loss of profits, goodwill, use, data, or other intangible losses.
11.3 Our total liability to you for any claims arising from your use of the Service shall not exceed the total fees paid by you to us in the thirty (30) days preceding the event giving rise to the claim.
11.4 The Service is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind, either express or implied.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

12. Indemnification

You agree to indemnify, defend, and hold harmless T's Verify and its affiliates, officers, directors, employees, and agents from and against any and all claims, damages, obligations, losses, liabilities, costs, and expenses arising from:
  - Your use of the Service.
  - Your violation of these Terms.
  - Your violation of any third-party rights.
  - Any activity conducted under your account.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

13. Termination

13.1 We may terminate or suspend your account and bar access to the Service immediately, without prior notice or liability, under our sole discretion, for any reason including but not limited to a breach of these Terms.
13.2 Upon termination, your right to use the Service will immediately cease.
13.3 If you wish to terminate your account, you may simply discontinue using the Service or contact us to request account deletion.
13.4 Provisions of these Terms that by their nature should survive termination shall survive, including but not limited to: intellectual property provisions, warranty disclaimers, indemnification, and limitations of liability.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

14. Modification of Terms

14.1 We reserve the right to modify or replace these Terms at any time.
14.2 Material changes will be communicated to users via email or through the Platform at least 30 days before they take effect.
14.3 By continuing to access or use our Service after any revisions become effective, you agree to be bound by the revised Terms.
14.4 If you do not agree to the new Terms, you must stop using the Service.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

15. Governing Law and Dispute Resolution

15.1 These Terms shall be governed by and construed in accordance with the laws of the Federal Democratic Republic of Ethiopia.
15.2 Any disputes arising out of or relating to these Terms or the Service shall be resolved through amicable negotiation between the parties.
15.3 If the dispute cannot be resolved through negotiation within thirty (30) days, the parties agree to submit the dispute to mediation in Addis Ababa, Ethiopia.
15.4 If mediation fails, the dispute shall be finally resolved by the courts of Addis Ababa, Ethiopia.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

16. Severability

If any provision of these Terms is held to be unenforceable or invalid, such provision will be changed and interpreted to accomplish the objectives of such provision to the greatest extent possible under applicable law, and the remaining provisions will continue in full force and effect.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

17. Entire Agreement

These Terms, together with our Privacy Policy, constitute the entire agreement between you and T's Verify regarding your use of the Service, superseding any prior agreements between you and T's Verify.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

18. Contact Information

If you have any questions about these Terms, please contact us:

Email: zagolinv@gmail.com
Address: Addis Ababa, Ethiopia
Website: https://www.tsverifyapp.com/`;

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
