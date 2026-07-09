/**
 * Cloud Functions — Buxoro POS (poster-ae945).
 * BACKEND-TAYYORGARLIK.md §4 (kunlik agregatsiya), §5 (atomik to'lov),
 * §12.4 (xodim boshqaruvi: Admin SDK).
 *
 * Deploy (foydalanuvchi mashinasida):
 *   cd functions && npm install
 *   firebase deploy --only functions
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ─────────────────── Push: yangi chek → owner'ga bildirishnoma ───────────────────
// Klient login'da `cafe_{cafeId}_owner` topic'iga obuna bo'ladi (owner qurilmalari).
exports.notifySale = onDocumentCreated("cafes/{cafeId}/receipts/{rid}", async (event) => {
  const d = event.data ? event.data.data() : null;
  if (!d) return;
  if ((d.status || "") === "Возврат") return; // vozvrat yangi savdo emas
  const cafeId = event.params.cafeId;
  const sum = Number(d.sum || 0).toLocaleString("ru-RU").replace(/ /g, " ");
  const body = `${sum} сум · ${d.payment || "—"} · ${d.waiter || ""}`.trim();
  try {
    await getMessaging().send({
      topic: `cafe_${cafeId}_owner`,
      notification: { title: `Новый чек №${d.id}`, body },
      data: { type: "sale", cafeId, receiptId: String(d.id || "") },
    });
  } catch (e) {
    console.error("notifySale send failed", e);
  }
});

// ── Yordamchilar ──

function employeeEmail(login, cafeId) {
  const safe = String(login).trim().toLowerCase().replace(/[^a-z0-9._-]/g, "");
  return `${safe}@${cafeId}.buxoropos.app`;
}

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Kirish kerak (login).");
  }
  return request.auth.uid;
}

/** Chaqiruvchi shu kafening owner yoki menejeri ekanini tekshiradi. */
async function assertManager(cafeId, uid) {
  if (!cafeId) throw new HttpsError("invalid-argument", "cafeId kerak.");
  const cafeSnap = await db.doc(`cafes/${cafeId}`).get();
  if (!cafeSnap.exists) throw new HttpsError("not-found", "Kafe topilmadi.");
  if (cafeSnap.get("ownerUid") === uid) return "owner";
  const empSnap = await db.doc(`cafes/${cafeId}/employees/${uid}`).get();
  const role = empSnap.exists ? empSnap.get("role") : null;
  if (role === "Управляющий") return "manager";
  throw new HttpsError("permission-denied", "Faqat egasi yoki menejer.");
}

// ─────────────────── §12.4: Xodim boshqaruvi ───────────────────

/** Owner yangi xodim yaratadi (Auth user + Firestore doc). */
exports.createEmployee = onCall(async (request) => {
  const uid = requireAuth(request);
  const { cafeId, login, password, name, role, phone = "", pin = "" } = request.data || {};
  await assertManager(cafeId, uid);
  if (!login || !password || password.length < 6) {
    throw new HttpsError("invalid-argument", "login va parol (≥6) kerak.");
  }
  const email = employeeEmail(login, cafeId);
  const user = await getAuth().createUser({ email, password, displayName: name });

  // Keyingi id (mavjud xodimlar bo'yicha).
  const empCol = db.collection(`cafes/${cafeId}/employees`);
  const existing = await empCol.get();
  const nextId = existing.empty
    ? 1
    : Math.max(...existing.docs.map((d) => Number(d.get("id") || 0))) + 1;

  await empCol.doc(user.uid).set({
    id: nextId,
    uid: user.uid,
    name: name || login,
    role: role || "Официант",
    pin: pin || "",
    phone,
    login,
    active: true,
    revenue: 0,
    checks: 0,
    lastLogin: null,
    createdAt: FieldValue.serverTimestamp(),
  });
  return { uid: user.uid, id: nextId };
});

/** Xodimni enable/disable qilish (Auth disabled + doc.active). */
exports.setEmployeeActive = onCall(async (request) => {
  const callerUid = requireAuth(request);
  const { cafeId, uid, active } = request.data || {};
  await assertManager(cafeId, callerUid);
  if (!uid) throw new HttpsError("invalid-argument", "uid kerak.");
  await getAuth().updateUser(uid, { disabled: !active });
  await db.doc(`cafes/${cafeId}/employees/${uid}`).update({ active: !!active });
  return { ok: true };
});

/** Xodimni o'chirish (Auth user + doc). Owner'ni o'chirib bo'lmaydi. */
exports.deleteEmployee = onCall(async (request) => {
  const callerUid = requireAuth(request);
  const { cafeId, uid } = request.data || {};
  await assertManager(cafeId, callerUid);
  if (!uid) throw new HttpsError("invalid-argument", "uid kerak.");
  const cafeSnap = await db.doc(`cafes/${cafeId}`).get();
  if (cafeSnap.get("ownerUid") === uid) {
    throw new HttpsError("failed-precondition", "Egani o'chirib bo'lmaydi.");
  }
  await getAuth().deleteUser(uid).catch(() => {});
  await db.doc(`cafes/${cafeId}/employees/${uid}`).delete();
  return { ok: true };
});

// ─────────────────── §5: Atomik to'lov (server-authoritative) ───────────────────

/**
 * Sotuvni atomik yozadi: receipt + kassa balansi + kassir stats +
 * mijoz bonus/totalSpent + ingredient qoldig'i. (Klient tarafidagi
 * repository.completePayment o'rniga server tomonda ishlatish mumkin.)
 */
exports.completePayment = onCall(async (request) => {
  const uid = requireAuth(request);
  const {
    cafeId, receipt, cashAmount = 0, employeeUid = null, clientId = null,
    bonusSpent = 0, bonusEarned = 0, stockDeltas = [],
  } = request.data || {};
  if (!cafeId || !receipt || receipt.id == null) {
    throw new HttpsError("invalid-argument", "cafeId va receipt kerak.");
  }
  // Kirish huquqi: shu kafe a'zosi bo'lishi kerak.
  const memberSnap = await db.doc(`cafes/${cafeId}/employees/${uid}`).get();
  const isOwner = (await db.doc(`cafes/${cafeId}`).get()).get("ownerUid") === uid;
  if (!memberSnap.exists && !isOwner) {
    throw new HttpsError("permission-denied", "Bu kafega ruxsat yo'q.");
  }

  const c = `cafes/${cafeId}`;
  await db.runTransaction(async (tx) => {
    tx.set(db.doc(`${c}/receipts/${receipt.id}`), {
      ...receipt,
      createdAt: FieldValue.serverTimestamp(),
    });
    if (cashAmount) {
      const cashRef = db.doc(`${c}/accounts/1`);
      const cashSnap = await tx.get(cashRef);
      tx.update(cashRef, { balance: (cashSnap.get("balance") || 0) + cashAmount });
    }
    if (employeeUid) {
      const eRef = db.doc(`${c}/employees/${employeeUid}`);
      const eSnap = await tx.get(eRef);
      if (eSnap.exists) {
        tx.update(eRef, {
          revenue: (eSnap.get("revenue") || 0) + (receipt.sum || 0),
          checks: (eSnap.get("checks") || 0) + 1,
        });
      }
    }
    if (clientId != null) {
      const cliRef = db.doc(`${c}/clients/${clientId}`);
      const cliSnap = await tx.get(cliRef);
      if (cliSnap.exists) {
        tx.update(cliRef, {
          bonus: (cliSnap.get("bonus") || 0) - bonusSpent + bonusEarned,
          totalSpent: (cliSnap.get("totalSpent") || 0) + (receipt.sum || 0),
        });
      }
    }
    for (const d of stockDeltas) {
      const iRef = db.doc(`${c}/ingredients/${d.ingredientId}`);
      const iSnap = await tx.get(iRef);
      if (iSnap.exists) {
        const v = (iSnap.get("stock") || 0) - d.amount;
        tx.update(iRef, { stock: v < 0 ? 0 : v });
      }
    }
  });
  return { ok: true };
});

// ─────────────────── §4: Kunlik agregatsiya (hosila statistika) ───────────────────

/**
 * Har kuni 00:10 (Asia/Samarkand) — kechagi kun uchun har kafega
 * cafes/{cafeId}/stats/{YYYY-MM-DD} hujjatini hisoblab yozadi.
 * Manba: receipts (createdAt bo'yicha). Hosila skalarlar (revenue, profit,
 * checks, byHour, paymentMethods) qayta hisoblanadi — §4 "manba vs hosila".
 */
exports.dailyAggregate = onSchedule(
  { schedule: "every day 00:10", timeZone: "Asia/Samarkand" },
  async () => {
    const now = new Date();
    const start = new Date(now); start.setDate(start.getDate() - 1); start.setHours(0, 0, 0, 0);
    const end = new Date(start); end.setDate(end.getDate() + 1);
    const dateKey = start.toISOString().slice(0, 10);
    const startTs = Timestamp.fromDate(start);
    const endTs = Timestamp.fromDate(end);

    const cafes = await db.collection("cafes").get();
    for (const cafe of cafes.docs) {
      const recs = await db
        .collection(`cafes/${cafe.id}/receipts`)
        .where("createdAt", ">=", startTs)
        .where("createdAt", "<", endTs)
        .get();

      let revenue = 0, profit = 0, checks = 0;
      const byHour = new Array(24).fill(0);
      const paymentMethods = { "Наличные": 0, "Карточка": 0, "Бонусы": 0 };
      for (const r of recs.docs) {
        if (r.get("status") === "Возврат") continue;
        const sum = r.get("sum") || 0;
        revenue += sum;
        profit += r.get("profit") || 0;
        checks += 1;
        const ts = r.get("createdAt");
        if (ts && ts.toDate) byHour[ts.toDate().getHours()] += sum;
        const pay = String(r.get("payment") || "");
        if (pay.includes("Налич")) paymentMethods["Наличные"] += sum;
        else if (pay.includes("Карт")) paymentMethods["Карточка"] += sum;
        else if (pay.includes("Бонус")) paymentMethods["Бонусы"] += sum;
      }
      await db.doc(`cafes/${cafe.id}/stats/${dateKey}`).set({
        date: dateKey,
        revenue,
        profit,
        checks,
        avgCheck: checks ? Math.round(revenue / checks) : 0,
        byHour,
        paymentMethods,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }
);
