// Backend per-bank verification. MUST run on a server hosted IN ETHIOPIA,
// because the CBE / BOA verification pages only respond from inside Ethiopia.
// Express route: POST /verify/:bank  body: { reference, amount, receiverAccount,
//                                            accountLast8, qr }

const express = require('express');
const router = express.Router();

// 10s timeout helper
async function fetchWithTimeout(url, opts = {}, ms = 10000) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), ms);
  try {
    return await fetch(url, { ...opts, signal: ctrl.signal });
  } finally {
    clearTimeout(t);
  }
}

// ---- CBE: apps.cbe.com.et  (needs reference + last 8 digits of the account) --
async function verifyCbe({ reference, accountLast8 }) {
  if (!reference || !accountLast8) return { found: false, error: 'missing ref/account' };
  const url = `https://apps.cbe.com.et:100/?id=${reference}${accountLast8}`;
  const res = await fetchWithTimeout(url);
  if (!res.ok) return { found: false, error: `cbe http ${res.status}` };
  const html = await res.text();
  const amount = parseAmount(html);
  const receiver = parseReceiver(html);
  if (!amount) return { found: false, error: 'cbe parse failed' };
  return { found: true, amount, receiverAccount: receiver };
}

// ---- BOA: decode the QR -> official verify URL -> fetch ----------------------
async function verifyBoa({ qr }) {
  if (!qr) return { found: false, error: 'no qr' };
  if (!/^https?:\/\/[^/]*abyssinia/i.test(qr) &&
      !/bankofabyssinia|boa/i.test(qr)) {
    return { found: false, error: 'qr not an official BOA url' };
  }
  const res = await fetchWithTimeout(qr);
  if (!res.ok) return { found: false, error: `boa http ${res.status}` };
  const html = await res.text();
  const amount = parseAmount(html);
  const receiver = parseReceiver(html);
  if (!amount) return { found: false, error: 'boa parse failed' };
  return { found: true, amount, receiverAccount: receiver };
}

// ---- Telebirr: transactioninfo.ethiotelecom.et/receipt/{no} ------------------
async function verifyTelebirr({ reference }) {
  if (!reference) return { found: false, error: 'no reference' };
  const url = `https://transactioninfo.ethiotelecom.et/receipt/${reference}`;
  const res = await fetchWithTimeout(url);
  if (!res.ok) return { found: false, error: `telebirr http ${res.status}` };
  const html = await res.text();
  const amount = parseAmount(html);
  const receiver = parseReceiver(html);
  if (!amount) return { found: false, error: 'telebirr parse failed' };
  return { found: true, amount, receiverAccount: receiver };
}

// ---- Awash: attempts QR-based verification (similar to BOA). -----------------
// Falls back to manual review if no QR is present.
async function verifyAwash({ reference, qr, amount, receiverAccount }) {
  // If a QR URL is provided, try to fetch and parse it (Awash receipts include QR codes)
  if (qr && /^https?:\/\//i.test(qr)) {
    try {
      const res = await fetchWithTimeout(qr, {}, 8000);
      if (res.ok) {
        const html = await res.text();
        const parsedAmount = parseAmount(html);
        const receiver = parseReceiver(html);
        if (parsedAmount) {
          return { found: true, amount: parsedAmount, receiverAccount: receiver };
        }
      }
    } catch (_) {
      // QR fetch failed — fall through to manual review
    }
  }
  // For reference-based lookup without a QR, return needs_review instead of hard failure
  if (reference) {
    return { found: false, needsReview: true, error: 'awash requires manual review — check statement' };
  }
  return { found: false, needsReview: true, error: 'awash has no public lookup — review/reconcile' };
}

router.post('/verify/:bank', async (req, res) => {
  try {
    const b = req.params.bank;
    const body = req.body || {};
    let out;
    if (b === 'cbe') out = await verifyCbe(body);
    else if (b === 'boa') out = await verifyBoa(body);
    else if (b === 'telebirr') out = await verifyTelebirr(body);
    else if (b === 'awash') out = await verifyAwash(body);
    else out = { found: false, error: `no verifier for ${b}` };
    res.json(out);
  } catch (e) {
    res.json({ found: false, error: String(e.message || e) });
  }
});

function parseAmount(html) {
  const m = html.match(/([\d,]+\.\d{2})\s*ETB/i) || html.match(/ETB\s*([\d,]+\.\d{2})/i);
  return m ? Number(m[1].replace(/,/g, '')) : null;
}
function parseReceiver(html) {
  const m = html.match(/(?:credited to|receiver|account number)[^0-9]*([0-9*]{4,})/i);
  return m ? m[1] : null;
}

module.exports = router;
