const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp }     = require("firebase-admin/app");
const { getFirestore }      = require("firebase-admin/firestore");
const { getMessaging }      = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

// ── Helpers ──────────────────────────────────────────────────────────────────

async function getTokensForUsers(uids) {
  const tokens = [];
  for (const uid of uids) {
    const snap = await db
      .collection("users").doc(uid).collection("fcmTokens").get();
    snap.forEach(d => { if (d.data().token) tokens.push(d.data().token); });
  }
  return tokens;
}

async function sendPush(tokens, title, body, data = {}) {
  if (tokens.length === 0) return;
  // FCM allows max 500 tokens per multicast request
  for (let i = 0; i < tokens.length; i += 500) {
    await getMessaging().sendEachForMulticast({
      tokens: tokens.slice(i, i + 500),
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v ?? "")])
      ),
      webpush: {
        notification: { icon: "/icons/Icon-192.png", badge: "/icons/Icon-192.png" },
        fcmOptions: { link: "/" },
      },
    });
  }
}

// ── Trigger: new message in channels/{channelId}/messages/{messageId} ────────
// Handles both org-channel messages and DM messages (both stored under
// channels/{id}/messages/ by the Flutter app).

exports.onNewMessage = onDocumentCreated(
  "channels/{channelId}/messages/{messageId}",
  async (event) => {
    const msg       = event.data.data();
    const channelId = event.params.channelId;
    const senderId  = msg.authorId;
    if (!senderId) return;

    // Read the flat channel-metadata doc (written by sendMessage in Flutter)
    const metaDoc = await db.collection("channels").doc(channelId).get();
    const meta    = metaDoc.exists ? metaDoc.data() : {};
    const orgId   = meta.orgId;

    if (orgId) {
      // ── Org channel message ──────────────────────────────────────────────
      const orgDoc = await db.collection("organizations").doc(orgId).get();
      if (!orgDoc.exists) return;

      const memberIds  = (orgDoc.data()?.memberIds ?? []).filter(uid => uid !== senderId);
      const tokens     = await getTokensForUsers(memberIds);
      const channelName = meta.channelName || channelId;
      const preview    = (msg.content || (msg.imageUrls?.length ? "📷 Image" : "")).substring(0, 120);

      await sendPush(
        tokens,
        `#${channelName}`,
        `${msg.authorName || "Someone"}: ${preview}`,
        { type: "channel", channelId, orgId, shellId: meta.shellId || "" }
      );
    } else {
      // ── DM message ──────────────────────────────────────────────────────
      const dmDoc = await db.collection("dms").doc(channelId).get();
      if (!dmDoc.exists) return;

      const participantIds = (dmDoc.data()?.participantIds ?? []).filter(uid => uid !== senderId);
      const tokens         = await getTokensForUsers(participantIds);
      const preview        = (msg.content || (msg.imageUrls?.length ? "📷 Image" : "")).substring(0, 120);

      await sendPush(
        tokens,
        msg.authorName || "New message",
        preview,
        { type: "dm", dmId: channelId }
      );
    }
  }
);
