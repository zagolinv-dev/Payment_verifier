// POST /create-waiter
// Body: { fullName, email, password, managerId }
// Header: x-manager-token  (the manager's JWT from Supabase)
//
// Set environment variables before starting the server:
//   SUPABASE_URL=https://your-project.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

const express = require('express');
const { createClient } = require('@supabase/supabase-js');
const router = express.Router();

router.post('/create-waiter', async (req, res) => {
  try {
    const { fullName, email, password, managerId } = req.body;

    if (!fullName || !email || !password || !managerId) {
      return res.status(400).json({ error: 'fullName, email, password and managerId are required' });
    }

    const url = process.env.SUPABASE_URL;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!url || !serviceKey) {
      return res.status(500).json({ error: 'Server not configured (missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY)' });
    }

    // Use service role — bypasses email rate limits and RLS
    const admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // Create the auth user with email already confirmed
    const { data, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName, role: 'WAITRESS', owner_id: managerId },
    });

    if (createError) return res.status(400).json({ error: createError.message });

    const newUserId = data.user.id;

    // Insert profile row (trigger may do this too, but upsert is safe)
    const { error: profileError } = await admin.from('profiles').upsert({
      id: newUserId,
      email,
      full_name: fullName,
      role: 'WAITRESS',
      owner_id: managerId,
      status: 'APPROVED',
      created_at: new Date().toISOString(),
    });

    if (profileError) return res.status(400).json({ error: profileError.message });

    return res.json({ success: true, userId: newUserId });
  } catch (e) {
    console.error('[create-waiter]', e);
    return res.status(500).json({ error: e.message ?? String(e) });
  }
});

module.exports = router;
