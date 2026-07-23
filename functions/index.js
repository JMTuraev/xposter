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

// O-8: ruxsat etilgan xodim rollari (allowlist). 'Владелец' — bu xodim roli
// emas (owner faqat ownerUid orqali aniqlanadi), shuning uchun ro'yxatda yo'q.
const ALLOWED_ROLES = [
  "Управляющий", "Администратор зала", "Официант", "Повар", "Маркетолог",
];

// ─────────────────── §12.4: Xodim boshqaruvi ───────────────────

/** Owner yangi xodim yaratadi (Auth user + Firestore doc).
 *  HOLAT-16: PIN ochiq matnda saqlanmaydi — client `pinHash`/`pinSalt`
 *  yuboradi (lib/utils/pin_hash.dart bilan bir xil sxema). Eski client
 *  yuborgan `pin` (ochiq matn) legacy sifatida qabul qilinadi. */
exports.createEmployee = onCall(async (request) => {
  const uid = requireAuth(request);
  const { cafeId, login, password, name, role, phone = "", pin = "",
          pinHash = null, pinSalt = null } = request.data || {};
  await assertManager(cafeId, uid);
  if (!login || !password || password.length < 6) {
    throw new HttpsError("invalid-argument", "login va parol (≥6) kerak.");
  }
  // O-8: rol allowlist — menejer ixtiyoriy/yuqoriroq rol (masalan 'Владелец')
  // yoki mavjud bo'lmagan satr bera olmasin.
  if (role && !ALLOWED_ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", "Noto'g'ri rol.");
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
    pin: pinHash ? "" : (pin || ""), // hash bo'lsa ochiq matn yozilmaydi
    pinSalt: pinSalt || null,
    pinHash: pinHash || null,
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
  // Y-3: egani (owner) bloklab bo'lmaydi — deleteEmployee'dagi kabi himoya.
  // Aks holda rogue menejer owner Auth'ini disabled qilib boshqaruvni tortib olardi.
  const cafeSnap = await db.doc(`cafes/${cafeId}`).get();
  if (cafeSnap.get("ownerUid") === uid) {
    throw new HttpsError("failed-precondition", "Egani bloklab bo'lmaydi.");
  }
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

// ─────────────────── Google Play: "Удалить аккаунт" (o'z akkauntini o'chirish) ───────────────────

/**
 * Foydalanuvchi O'Z akkauntini butunlay o'chiradi (Google Play "Account
 * deletion" talabi: play.google.com/console → User data). Reauth kerak emas —
 * chaqiruvchi allaqachon login qilgan va faqat O'ZINI o'chiradi.
 *
 * Owner  → egalik qilgan BARCHA kafelar (subkolleksiyalari bilan), ulardagi
 *          xodimlarning Auth userlari, cafeCodes, owners/{uid} va owner Auth.
 * Xodim → faqat o'z employees hujjati + o'z Auth user'i.
 * Barcha Firestore ma'lumot (cheklar, tranzaksiyalar, mijozlar, sklad...)
 * kafe bilan birga rekursiv o'chadi — hech qanday shaxsiy ma'lumot qolmaydi.
 */
exports.deleteAccount = onCall(async (request) => {
  const uid = requireAuth(request);

  const ownerSnap = await db.doc(`owners/${uid}`).get();
  if (ownerSnap.exists) {
    const cafesSnap = await db.collection("cafes").where("ownerUid", "==", uid).get();
    for (const cafeDoc of cafesSnap.docs) {
      const cafeId = cafeDoc.id;
      // 1) Xodimlarning Auth userlari (owner'ning o'zidan tashqari).
      const empsSnap = await db.collection(`cafes/${cafeId}/employees`).get();
      for (const emp of empsSnap.docs) {
        if (emp.id === uid) continue;
        await getAuth().deleteUser(emp.id).catch(() => {});
      }
      // 2) cafeCodes yozuvlari (kod → cafeId).
      const codesSnap = await db.collection("cafeCodes").where("cafeId", "==", cafeId).get();
      for (const codeDoc of codesSnap.docs) {
        await codeDoc.ref.delete().catch(() => {});
      }
      // 3) Kafe hujjati + BARCHA subkolleksiyalar (rekursiv).
      await db.recursiveDelete(cafeDoc.ref);
    }
    await db.doc(`owners/${uid}`).delete().catch(() => {});
    await getAuth().deleteUser(uid).catch(() => {}); // oxirida — o'zini
    return { ok: true, scope: "owner" };
  }

  // Xodim: o'z yozuvi (uid = docId) + Auth.
  const empQ = await db.collectionGroup("employees").where("uid", "==", uid).limit(1).get();
  if (!empQ.empty) {
    await empQ.docs[0].ref.delete().catch(() => {});
  }
  await getAuth().deleteUser(uid).catch(() => {});
  return { ok: true, scope: "employee" };
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
  // Y-12: bu CF klientda ISHLATILMAYDI (klient WriteBatch qiladi) va idempotent
  // emas. Har a'zoga ochiq qoldirmaslik uchun faqat owner/menejerga cheklaymiz —
  // to'liq olib tashlash yoki idempotency kaliti bilan qayta yozish tavsiya etiladi.
  await assertManager(cafeId, uid);

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
    // O-6: sana/soatni Asia/Samarkand (UTC+5, DST yo'q) bo'yicha hisoblaymiz —
    // CF runtime UTC'da ishlaydi, aks holda kun oynasi 5 soat siljib, ertalabki
    // savdo oldingi kunga tushardi.
    const OFFSET = 5 * 3600 * 1000;
    const nowTk = new Date(Date.now() + OFFSET); // Tashkent "devor soati" (UTC metodlari bilan)
    // Kechagi Tashkent kuni [00:00, 24:00):
    const startTk = new Date(Date.UTC(nowTk.getUTCFullYear(), nowTk.getUTCMonth(), nowTk.getUTCDate() - 1, 0, 0, 0));
    const endTk = new Date(startTk.getTime() + 24 * 3600 * 1000);
    const dateKey = startTk.toISOString().slice(0, 10); // Tashkent sanasi (YYYY-MM-DD)
    // Firestore so'rovi haqiqiy UTC oynasida = Tashkent vaqti − offset.
    const startTs = Timestamp.fromDate(new Date(startTk.getTime() - OFFSET));
    const endTs = Timestamp.fromDate(new Date(endTk.getTime() - OFFSET));

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
        // O-6: Tashkent soati (UTC+5).
        if (ts && ts.toDate) byHour[new Date(ts.toDate().getTime() + OFFSET).getUTCHours()] += sum;
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

// ─────────────────── Super-admin konsoli (additive; superadmin.js) ───────────────────
// Mavjud funksiyalarga tegmaydi — faqat yangi 2 ta callable eksport qiladi.
const superadmin = require("./superadmin");
exports.superAdminList = superadmin.superAdminList;
exports.superAdminCafeDetail = superadmin.superAdminCafeDetail;
