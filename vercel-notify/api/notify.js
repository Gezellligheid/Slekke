const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getFirestore }                 = require('firebase-admin/firestore');
const { getMessaging }                 = require('firebase-admin/messaging');

// ── Logger ────────────────────────────────────────────────────────────────────
function log(level, msg, data) {
  const line = { ts: new Date().toISOString(), level, msg, ...data };
  console.log(JSON.stringify(line));
}

// ── Firebase Admin init (lazy singleton) ─────────────────────────────────────
function getApp() {
  if (getApps().length > 0) return getApps()[0];
  log('info', 'Initialising Firebase Admin');
  return initializeApp({
    credential: cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)),
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────
async function getTokensForUsers(db, uids) {
  log('info', 'Fetching FCM tokens', { recipientCount: uids.length, uids });
  const tokens = [];
  await Promise.all(
    uids.map(async (uid) => {
      const snap = await db
        .collection('users').doc(uid).collection('fcmTokens').get();
      const userTokens = [];
      snap.forEach((d) => {
        if (d.data().token) {
          tokens.push(d.data().token);
          userTokens.push({ token: d.data().token.slice(0, 20) + '…', platform: d.data().platform });
        }
      });
      log('info', 'Tokens for user', { uid, count: userTokens.length, tokens: userTokens });
    })
  );
  log('info', 'Total tokens collected', { total: tokens.length });
  return tokens;
}

async function sendPush(tokens, title, body, data) {
  if (tokens.length === 0) {
    log('warn', 'No tokens to send to — skipping FCM call');
    return 0;
  }
  log('info', 'Sending FCM multicast', { tokenCount: tokens.length, title, body, data });
  const app = getApp();
  let sent = 0;
  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const res = await getMessaging(app).sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v ?? '')])
      ),
      webpush: {
        notification: { icon: '/icons/Icon-192.png', badge: '/icons/Icon-192.png' },
        fcmOptions: { link: '/' },
      },
    });
    log('info', 'FCM batch result', {
      chunkIndex: i / 500,
      sent: res.successCount,
      failed: res.failureCount,
      errors: res.responses
        .filter((r) => !r.success)
        .map((r) => ({ code: r.error?.code, message: r.error?.message })),
    });
    sent += res.successCount;
  }
  return sent;
}

// ── Handler ───────────────────────────────────────────────────────────────────
module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  // Auth
  const secret = process.env.NOTIFY_SECRET;
  if (secret) {
    const auth = req.headers['authorization'] ?? '';
    if (auth !== `Bearer ${secret}`) {
      log('warn', 'Unauthorized request');
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }

  const {
    channelId, authorId, authorName,
    content, imageCount, orgId, shellId, channelName,
  } = req.body ?? {};

  log('info', 'Received notify request', {
    channelId, authorId, authorName,
    contentPreview: content?.substring(0, 40),
    imageCount, orgId, shellId, channelName,
    type: orgId ? 'channel' : 'dm',
  });

  if (!channelId || !authorId) {
    log('error', 'Missing required fields', { channelId, authorId });
    return res.status(400).json({ error: 'Missing channelId or authorId' });
  }

  const app = getApp();
  const db  = getFirestore(app);
  const preview = content?.substring(0, 120) || (imageCount > 0 ? '📷 Image' : '…');
  let sent = 0;

  try {
    if (orgId) {
      // ── Org channel ──────────────────────────────────────────────────────
      log('info', 'Looking up org', { orgId });
      const orgDoc = await db.collection('organizations').doc(orgId).get();
      if (!orgDoc.exists) {
        log('warn', 'Org not found', { orgId });
        return res.status(200).json({ sent: 0 });
      }
      const allMembers = orgDoc.data()?.memberIds ?? [];
      const memberIds  = allMembers.filter((id) => id !== authorId);
      log('info', 'Org members', { total: allMembers.length, recipients: memberIds.length });

      const tokens = await getTokensForUsers(db, memberIds);
      sent = await sendPush(
        tokens,
        `#${channelName || channelId}`,
        `${authorName || 'Someone'}: ${preview}`,
        { type: 'channel', channelId, orgId, shellId: shellId ?? '' }
      );
    } else {
      // ── DM ───────────────────────────────────────────────────────────────
      log('info', 'Looking up DM', { dmId: channelId });
      const dmDoc = await db.collection('dms').doc(channelId).get();
      if (!dmDoc.exists) {
        log('warn', 'DM not found', { dmId: channelId });
        return res.status(200).json({ sent: 0 });
      }
      const allParticipants = dmDoc.data()?.participantIds ?? [];
      const participantIds  = allParticipants.filter((id) => id !== authorId);
      log('info', 'DM participants', { total: allParticipants.length, recipients: participantIds.length });

      const tokens = await getTokensForUsers(db, participantIds);
      sent = await sendPush(
        tokens,
        authorName || 'New message',
        preview,
        { type: 'dm', dmId: channelId }
      );
    }
  } catch (err) {
    log('error', 'Unhandled error', { message: err.message, stack: err.stack });
    return res.status(500).json({ error: err.message });
  }

  log('info', 'Done', { sent });
  return res.status(200).json({ sent });
};
