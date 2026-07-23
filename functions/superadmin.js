/**
 * Super-admin konsoli — backend callable'lar (poster-ae945).
 * Qo'shimcha modul: mavjud index.js funksiyalariga TEGMAYDI (additive).
 * Kirish: EMAIL/PAROL (Firebase Auth) → callable email allowlist'ni tekshiradi.
 * Ma'lumot faqat Admin SDK orqali o'qiladi (Firestore rules OCHILMAYDI) —
 * zal egalari bir-birining ma'lumotini ko'ra olmaydi.
 *
 * index.js oxiriga qo'shildi:
 *   const superadmin = require("./superadmin");
 *   exports.superAdminList = superadmin.superAdminList;
 *   exports.superAdminCafeDetail = superadmin.superAdminCafeDetail;
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const db = getFirestore();

// ── Super-admin email allowlist (server tomonda; mijoz o'zgartira olmaydi) ──
const SUPERADMIN_EMAILS = [
  "jafaralituraev@gmail.com",
];

function tsMs(v) {
  return v && typeof v.toMillis === "function" ? v.toMillis() : null;
}

async function countOf(path) {
  try {
    const s = await db.collection(path).count().get();
    return s.data().count;
  } catch (_) {
    // firebase-admin eski bo'lsa count() yo'q — zaxira: hujjatlarni sanaymiz.
    const s = await db.collection(path).get();
    return s.size;
  }
}

/** Chaqiruvchi super-admin ekanini tekshiradi; rad etilgan urinishni audit qiladi. */
function assertSuperAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Kirish kerak (email/parol).");
  }
  const email = String(request.auth.token.email || "").toLowerCase();
  if (!SUPERADMIN_EMAILS.includes(email)) {
    db.collection("superAdminAudit").add({
      at: FieldValue.serverTimestamp(),
      email,
      uid: request.auth.uid,
      action: "denied",
    }).catch(() => {});
    throw new HttpsError("permission-denied", "Bu аккаунт super-admin emas.");
  }
  return email;
}

async function ownerInfo(cafeId, ownerUid) {
  let name = "", phone = "", email = "", login = "";
  if (!ownerUid) return { name, phone, email, login };
  try {
    const emp = await db.doc(`cafes/${cafeId}/employees/${ownerUid}`).get();
    if (emp.exists) {
      name = emp.get("name") || "";
      phone = emp.get("phone") || "";
      login = emp.get("login") || "";
    }
  } catch (_) { /* ignore */ }
  try {
    const own = await db.doc(`owners/${ownerUid}`).get();
    if (own.exists) {
      email = own.get("email") || "";
      if (!name) name = own.get("name") || "";
    }
  } catch (_) { /* ignore */ }
  return { name, phone, email, login };
}

// ─────────────────── superAdminList: barcha kafelar ───────────────────
exports.superAdminList = onCall(async (request) => {
  const email = assertSuperAdmin(request);
  const cafes = await db.collection("cafes").get();
  const out = [];
  for (const c of cafes.docs) {
    const d = c.data();
    // Test markazi efemer kafelarini dashboardда ko'rsatmaymiz.
    if (String(d.name || "").startsWith("__SELFTEST")) continue;
    const owner = await ownerInfo(c.id, d.ownerUid);
    const [clients, products, employees] = await Promise.all([
      countOf(`cafes/${c.id}/clients`),
      countOf(`cafes/${c.id}/products`),
      countOf(`cafes/${c.id}/employees`),
    ]);
    out.push({
      id: c.id,
      name: d.name || "",
      spot: d.spot || "",
      address: d.address || "",
      code: d.code || "",
      timezone: d.timezone || "",
      currency: d.currency || "",
      owner,
      subStatus: (d.subscription && d.subscription.status) || "trial",
      paidUntil: tsMs(d.paidUntil),
      trialUntil: tsMs(d.trialUntil),
      createdAt: tsMs(d.createdAt),
      counts: { clients, products, employees },
    });
  }
  // Audit: muvaffaqiyatli kirish/ko'rish.
  db.collection("superAdminAudit").add({
    at: FieldValue.serverTimestamp(), email, uid: request.auth.uid,
    action: "list", cafes: out.length,
  }).catch(() => {});
  return { cafes: out, serverNow: Date.now() };
});

// ─────────────────── superAdminCafeDetail: bitta kafe tafsiloti ───────────────────
exports.superAdminCafeDetail = onCall(async (request) => {
  const email = assertSuperAdmin(request);
  const { cafeId } = request.data || {};
  if (!cafeId) throw new HttpsError("invalid-argument", "cafeId kerak.");
  const cafeSnap = await db.doc(`cafes/${cafeId}`).get();
  if (!cafeSnap.exists) throw new HttpsError("not-found", "Kafe topilmadi.");
  const d = cafeSnap.data();
  const owner = await ownerInfo(cafeId, d.ownerUid);

  const [clientsS, productsS, employeesS, accountsS, txS, recsS] = await Promise.all([
    db.collection(`cafes/${cafeId}/clients`).limit(1000).get().catch(() => ({ docs: [] })),
    db.collection(`cafes/${cafeId}/products`).limit(1000).get().catch(() => ({ docs: [] })),
    db.collection(`cafes/${cafeId}/employees`).get().catch(() => ({ docs: [] })),
    db.collection(`cafes/${cafeId}/accounts`).get().catch(() => ({ docs: [] })),
    db.collection(`cafes/${cafeId}/transactions`).limit(80).get().catch(() => ({ docs: [] })),
    db.collection(`cafes/${cafeId}/receipts`).limit(40).get().catch(() => ({ docs: [] })),
  ]);

  const clients = clientsS.docs.map((x) => {
    const m = x.data();
    return {
      name: m.name || "", phone: m.phone || "", bonus: m.bonus || 0,
      debt: m.debt || 0, totalSpent: m.totalSpent || 0,
    };
  });
  const products = productsS.docs.map((x) => {
    const m = x.data();
    return {
      name: m.name || "", price: m.price || 0, categoryId: m.categoryId || null,
      barcode: m.barcode || "", type: m.type || "",
    };
  });
  const employees = employeesS.docs.map((x) => {
    const m = x.data();
    return {
      name: m.name || "", role: m.role || "", phone: m.phone || "",
      active: m.active !== false, revenue: m.revenue || 0, checks: m.checks || 0,
    };
  });
  const accounts = accountsS.docs.map((x) => {
    const m = x.data();
    return { name: m.name || "", type: m.type || "", balance: m.balance || 0 };
  });
  // Tranzaksiyalar — eng yangi 30 (id/created bo'yicha kamayuvchi, mijozda saralaymiz).
  const tx = txS.docs.map((x) => {
    const m = x.data();
    return {
      id: m.id || 0, amount: m.amount || 0, type: m.type || "",
      account: m.account || "", comment: m.comment || "",
      createdAt: tsMs(m.createdAt),
    };
  }).sort((a, b) => (b.id || 0) - (a.id || 0)).slice(0, 30);
  // Moliya jamlanmasi — tur bo'yicha yig'indi.
  const finance = {};
  for (const t of tx) {
    const k = t.type || "—";
    finance[k] = (finance[k] || 0) + (t.amount || 0);
  }
  const receipts = recsS.docs.map((x) => {
    const m = x.data();
    return { id: m.id || 0, sum: m.sum || 0, payment: m.payment || "", status: m.status || "" };
  }).sort((a, b) => (b.id || 0) - (a.id || 0)).slice(0, 20);

  db.collection("superAdminAudit").add({
    at: FieldValue.serverTimestamp(), email, uid: request.auth.uid,
    action: "detail", cafeId,
  }).catch(() => {});

  return {
    cafe: {
      id: cafeId, name: d.name || "", spot: d.spot || "", address: d.address || "",
      code: d.code || "", timezone: d.timezone || "", currency: d.currency || "",
      owner,
      subStatus: (d.subscription && d.subscription.status) || "trial",
      paidUntil: tsMs(d.paidUntil), trialUntil: tsMs(d.trialUntil), createdAt: tsMs(d.createdAt),
      loyalty: d.loyalty || null,
    },
    clients, products, employees, accounts, tx, finance, receipts,
    serverNow: Date.now(),
  };
});
