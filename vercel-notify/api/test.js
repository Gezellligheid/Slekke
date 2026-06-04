const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getMessaging }                 = require('firebase-admin/messaging');

function log(level, msg, data) {
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, ...data }));
}

function getApp() {
  if (getApps().length > 0) return getApps()[0];
  log('info', 'Initialising Firebase Admin');
  return initializeApp({ credential: cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)) });
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).end();

  const secret = process.env.NOTIFY_SECRET;
  if (secret && req.headers['authorization'] !== `Bearer ${secret}`) {
    log('warn', 'Unauthorized test request');
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { token } = req.body ?? {};
  if (!token) {
    log('error', 'Missing token in request body');
    return res.status(400).json({ error: 'Missing token' });
  }

  log('info', 'Sending test notification', { tokenPreview: token.slice(0, 20) + '…' });

  try {
    const result = await getMessaging(getApp()).send({
      token,
      notification: {
        title: '🔔 Slekke notifications work!',
        body:  'Push notifications are set up correctly.',
      },
      webpush: {
        notification: { icon: '/icons/Icon-192.png' },
        fcmOptions: { link: '/' },
      },
    });
    log('info', 'Test notification sent', { messageId: result });
    return res.status(200).json({ ok: true, messageId: result });
  } catch (err) {
    log('error', 'Failed to send test notification', { message: err.message, code: err.code });
    return res.status(500).json({ error: err.message, code: err.code });
  }
};
