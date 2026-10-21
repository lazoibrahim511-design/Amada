const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Helper to locate an employee document in the 'employees' collection.
 * Supports:
 * - Company-prefixed doc IDs: e.g. "lazo_2", "amada_1"
 * - Direct doc IDs: e.g. "admin_super_account", "lazo_admin", "1"
 * - Query by 'id' and 'companyCode'
 * - Query by 'id'
 */
async function findEmployee(empId, companyCode) {
  if (!empId) return null;
  const strId = String(empId).trim();
  const cleanComp = companyCode ? String(companyCode).trim().toLowerCase() : "";
  const employeesRef = admin.firestore().collection("employees");

  // 1. Try company-prefixed ID: "${companyCode}_${empId}"
  if (cleanComp && !strId.startsWith(`${cleanComp}_`)) {
    try {
      const snap = await employeesRef.doc(`${cleanComp}_${strId}`).get();
      if (snap.exists) return snap.data();
    } catch (_) {}
  }

  // 2. Try exact document ID
  try {
    const directSnap = await employeesRef.doc(strId).get();
    if (directSnap.exists) {
      const data = directSnap.data();
      if (!cleanComp || !data.companyCode || String(data.companyCode).toLowerCase() === cleanComp) {
        return data;
      }
    }
  } catch (_) {}

  // 3. Query by 'id' and 'companyCode'
  if (cleanComp) {
    try {
      const querySnap = await employeesRef
        .where("id", "==", strId)
        .where("companyCode", "==", cleanComp)
        .limit(1)
        .get();
      if (!querySnap.empty) return querySnap.docs[0].data();
    } catch (_) {}
  }

  // 4. Query by 'id' alone
  try {
    const idSnap = await employeesRef.where("id", "==", strId).limit(1).get();
    if (!idSnap.empty) return idSnap.docs[0].data();
  } catch (_) {}

  return null;
}

exports.onMessageCreated = onDocumentCreated("chat_rooms/{roomId}/messages/{messageId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const senderId = data.senderId;
  const receiverId = data.receiverId;
  const text = data.text;
  const companyCode = data.companyCode;

  if (!senderId || !receiverId || !text) {
    console.log("Missing senderId, receiverId, or text. Skipped.");
    return;
  }

  try {
    // 1. Resolve Sender Name
    let senderName = data.senderName;
    if (!senderName) {
      const sender = await findEmployee(senderId, companyCode);
      senderName = sender?.name || "New Message";
    }

    // 2. Resolve Receiver FCM Token
    const receiver = await findEmployee(receiverId, companyCode);
    if (!receiver) {
      console.log(`Receiver ${receiverId} (company: ${companyCode}) not found in employees collection.`);
      return;
    }

    const fcmToken = receiver.fcmToken;
    if (!fcmToken || !String(fcmToken).trim()) {
      console.log(`No active FCM token for receiver ${receiverId} (${receiver.name}).`);
      return;
    }

    const title = `Message from ${senderName}`;
    const bodyText = String(text);

    // 3. Construct FCM Payload with High Priority for Closed/Background Apps
    const message = {
      notification: {
        title: title,
        body: bodyText,
      },
      token: fcmToken,
      data: {
        type: "chat_message",
        messageId: String(event.params.messageId),
        senderId: String(senderId),
        senderName: String(senderName),
        receiverId: String(receiverId),
        companyCode: String(companyCode || ""),
        roomId: String(event.params.roomId),
        title: title,
        body: bodyText,
      },
      android: {
        priority: "high",
        collapseKey: String(event.params.roomId),
        notification: {
          tag: String(event.params.messageId),
          channelId: "chat_channel_id",
          sound: "default",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: bodyText,
            },
            sound: "default",
            badge: 1,
            contentAvailable: true,
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`Successfully sent message to receiver ${receiverId} (${receiver.name}):`, response);
  } catch (error) {
    console.error("Error sending push notification in Cloud Function:", error);
  }
});
