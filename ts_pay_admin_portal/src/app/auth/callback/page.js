"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabase";

function CallbackHandler() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [status, setStatus] = useState("Processing verification...");

  useEffect(() => {
    const handleCallback = async () => {
      const next = searchParams.get("next") || "/dashboard";

      const { data: { session }, error } = await supabase.auth.getSession();

      if (error || !session) {
        setStatus("Verification failed. Redirecting...");
        setTimeout(() => router.push("/"), 2000);
        return;
      }

      setStatus("Redirecting...");
      router.push(next);
    };

    handleCallback();
  }, [router, searchParams]);

  return (
    <div className="min-h-screen bg-zinc-50 flex flex-col items-center justify-center gap-4 p-4">
      <img src="/logo.png" alt="T's Verify" className="w-14 h-14 object-contain animate-pulse" />
      <div className="flex gap-1.5">
        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "0ms" }} />
        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "150ms" }} />
        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "300ms" }} />
      </div>
      <p className="text-sm text-zinc-400 font-medium">{status}</p>
    </div>
  );
}

export default function AuthCallbackPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-zinc-50 flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <img src="/logo.png" alt="T's Verify" className="w-14 h-14 object-contain animate-pulse" />
          <div className="flex gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "0ms" }} />
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "150ms" }} />
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-bounce" style={{ animationDelay: "300ms" }} />
          </div>
        </div>
      </div>
    }>
      <CallbackHandler />
    </Suspense>
  );
}
