/**
 * Super-admin TO'LIQ E2E TEST — har Cloud Function va rollar bo'yicha
 * Firestore Rules'ni JONLI tekshiradi (poster-ae945).
 *
 * Usul: izolyatsiya qilingan test-kafe + har rol uchun REAL auth akkaunt
 * (owner/manager/waiter/cook/outsider, ma'lum parol bilan) yaratiladi →
 * REST orqali har biriga idToken olinadi → callable'lar va client
 * yozuvlari o'sha tokenlar bilan chaqirilib, ruxsat/rad tekshiriladi →
 * oxirida deleteAccount (real CF) + fallback bilan HAMMASI tozalanadi.
 *
 * index.js: exports.superAdminRunE2E = require("./e2e").superAdminRunE2E;
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

const db = getFirestore();
const auth = getAuth();
const API_KEY = "AIzaSyBR9Rh3IKNnyLBdcxGvLlCPPG6KNgGeXLU";
const FN = "https://us-central1-poster-ae945.cloudfunctions.net";
const FS = "https://firestore.googleapis.com/v1/projects/poster-ae945/databases/(default)/documents";
const SUPERADMIN_EMAILS = ["jafaralituraev@gmail.com"];
const PW = "E2e!test-2026";

function assertSuperAdmin(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Kirish kerak.");
  const email = String(request.auth.token.email || "").toLowerCase();
  if (!SUPERADMIN_EMAILS.includes(email)) throw new HttpsError("permission-denied", "Super-admin emas.");
  return email;
}

async function signIn(email) {
  const r = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`,
    { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password: PW, returnSecureToken: true }) });
  const j = await r.json();
  if (!j.idToken) throw new Error("signIn " + email + ": " + JSON.stringify(j).slice(0, 120));
  return j.idToken;
}
async function callFn(name, tok, data) {
  const r = await fetch(`${FN}/${name}`, {
    method: "POST", headers: { "Authorization": "Bearer " + tok, "Content-Type": "application/json" },
    body: JSON.stringify({ data }),
  });
  const body = await r.text();
  let json = null; try { json = JSON.parse(body); } catch (_) {}
  return { status: r.status, json, body };
}
function fv(obj) {
  const f = {};
  for (const [k, v] of Object.entries(obj)) {
    if (typeof v === "number") f[k] = Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
    else if (typeof v === "boolean") f[k] = { booleanValue: v };
    else f[k] = { stringValue: String(v) };
  }
  return f;
}
async function fsCreate(collPath, docId, tok, obj) {
  const r = await fetch(`${FS}/${collPath}?documentId=${docId}`, {
    method: "POST", headers: { "Authorization": "Bearer " + tok, "Content-Type": "application/json" },
    body: JSON.stringify({ fields: fv(obj) }),
  });
  return r.status; // 200 = ruxsat, 403 = rad
}
async function fsPatch(docPath, tok, obj, mask) {
  const q = (mask || Object.keys(obj)).map((k) => `updateMask.fieldPaths=${k}`).join("&");
  const r = await fetch(`${FS}/${docPath}?${q}`, {
    method: "PATCH", headers: { "Authorization": "Bearer " + tok, "Content-Type": "application/json" },
    body: JSON.stringify({ fields: fv(obj) }),
  });
  return r.status;
}

exports.superAdminRunE2E = onCall({ timeoutSeconds: 540 }, async (request) => {
  assertSuperAdmin(request);
  const R = [];
  const add = (group, name, status, detail) => R.push({ group, name, status, detail: detail || "" });
  const ok = (cond, group, name, detail) => add(group, name, cond ? "pass" : "fail", detail);
  const t0 = Date.now();
  const sfx = Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36);

  const cafeRef = db.collection("cafes").doc();
  const cafeId = cafeRef.id;
  const created = []; // {uid} tozalash uchun
  const email = (r) => `e2e_${r}_${sfx}@e2etest.xposter.uz`;

  async function mkUser(role) {
    const u = await auth.createUser({ email: email(role), password: PW });
    created.push(u.uid);
    return u.uid;
  }

  try {
    // ── SETUP: 5 akkaunt + test-kafe ──
    const ownerU = await mkUser("owner");
    const mgrU = await mkUser("mgr");
    const waiterU = await mkUser("waiter");
    const cookU = await mkUser("cook");
    const outU = await mkUser("out"); // begona (kafe a'zosi emas)
    add("Настройка", "Тест-аккаунты созданы (владелец/менеджер/официант/повар/чужой)", "pass", "5 auth");

    await cafeRef.set({
      name: "__SELFTEST_E2E__", ownerUid: ownerU, spot: "E2E",
      subscription: { status: "active" },
      paidUntil: Timestamp.fromDate(new Date(Date.now() + 30 * 864e5)),
      createdAt: FieldValue.serverTimestamp(),
    });
    await db.doc(`owners/${ownerU}`).set({ email: email("owner"), name: "E2E Owner", cafeId });
    const emp = (uid, role, name) => db.doc(`cafes/${cafeId}/employees/${uid}`).set({
      id: 1, uid, name, role, active: true, revenue: 0, checks: 0, login: role,
    });
    await emp(ownerU, "Владелец", "E2E Owner");
    await emp(mgrU, "Управляющий", "E2E Manager");
    await emp(waiterU, "Официант", "E2E Waiter");
    await emp(cookU, "Повар", "E2E Cook");
    await db.doc(`cafes/${cafeId}/accounts/1`).set({ id: 1, name: "Касса", type: "Наличные", balance: 0 });
    await db.doc(`cafes/${cafeId}/ingredients/1`).set({ id: 1, name: "Молоко", stock: 1000, unit: "мл" });
    add("Настройка", "Тест-заведение и роли созданы", "pass", `cafe=${cafeId}`);

    // ── TOKENLAR ──
    const [ownerT, mgrT, waiterT, cookT, outT] = await Promise.all([
      signIn(email("owner")), signIn(email("mgr")), signIn(email("waiter")),
      signIn(email("cook")), signIn(email("out")),
    ]);
    add("Настройка", "Вход по всем ролям (idToken)", "pass", "5 токенов");

    // ── A. CALLABLE ФУНКЦИИ ──
    // createEmployee: менеджер → успех
    const ce = await callFn("createEmployee", mgrT, {
      cafeId, login: "kelner2_" + sfx, password: "Xemp!2026", name: "Второй официант", role: "Официант",
    });
    ok(ce.status === 200 && ce.json && ce.json.result && ce.json.result.uid, "A · Функции",
      "createEmployee (менеджер) создаёт сотрудника", `HTTP ${ce.status}`);
    if (ce.json && ce.json.result && ce.json.result.uid) created.push(ce.json.result.uid);

    // createEmployee: официант → запрет
    const ceW = await callFn("createEmployee", waiterT, { cafeId, login: "x_" + sfx, password: "Xemp!2026", name: "X", role: "Официант" });
    ok(ceW.status !== 200, "A · Функции", "createEmployee (официант) → ЗАПРЕЩЕНО", `HTTP ${ceW.status}`);

    // createEmployee: недопустимая роль → отказ
    const ceBad = await callFn("createEmployee", mgrT, { cafeId, login: "y_" + sfx, password: "Xemp!2026", name: "Y", role: "Владелец" });
    ok(ceBad.status !== 200, "A · Функции", "createEmployee с ролью «Владелец» → ОТКЛОНЕНО", `HTTP ${ceBad.status}`);

    // setEmployeeActive: менеджер отключает официанта → успех
    const sa = await callFn("setEmployeeActive", mgrT, { cafeId, uid: waiterU, active: false });
    ok(sa.status === 200, "A · Функции", "setEmployeeActive (менеджер) отключает официанта", `HTTP ${sa.status}`);
    await callFn("setEmployeeActive", mgrT, { cafeId, uid: waiterU, active: true }); // вернуть

    // setEmployeeActive: попытка заблокировать ВЛАДЕЛЬЦА → запрет
    const saOwn = await callFn("setEmployeeActive", mgrT, { cafeId, uid: ownerU, active: false });
    ok(saOwn.status !== 200, "A · Функции", "Блокировка владельца менеджером → ЗАПРЕЩЕНО", `HTTP ${saOwn.status}`);

    // completePayment: реальный CF, атомарная продажа
    const cp = await callFn("completePayment", mgrT, {
      cafeId,
      receipt: { id: 501, sum: 20000, profit: 15000, payment: "Наличные", status: "Продажа" },
      cashAmount: 20000, employeeUid: waiterU,
      stockDeltas: [{ ingredientId: 1, amount: 50 }],
    });
    ok(cp.status === 200, "A · Функции", "completePayment (реальный CF) — атомарная продажа", `HTTP ${cp.status}`);
    // проверка результата
    const bal = (await db.doc(`cafes/${cafeId}/accounts/1`).get()).get("balance");
    const stk = (await db.doc(`cafes/${cafeId}/ingredients/1`).get()).get("stock");
    const wrev = (await db.doc(`cafes/${cafeId}/employees/${waiterU}`).get()).get("revenue");
    ok(bal === 20000, "A · Функции", "  → касса +20 000", `баланс=${bal}`);
    ok(stk === 950, "A · Функции", "  → склад −50 (1000→950)", `остаток=${stk}`);
    ok(wrev === 20000, "A · Функции", "  → выручка официанта +20 000", `revenue=${wrev}`);

    // completePayment чужим (не член) → запрет
    const cpOut = await callFn("completePayment", outT, { cafeId, receipt: { id: 502, sum: 1 }, cashAmount: 1 });
    ok(cpOut.status !== 200, "A · Функции", "completePayment чужим аккаунтом → ЗАПРЕЩЕНО", `HTTP ${cpOut.status}`);

    // ── B. ПРАВИЛА ДОСТУПА (client REST, по ролям) ──
    // официант создаёт чек → разрешено (canSell + подписка активна)
    ok(await fsCreate(`cafes/${cafeId}/receipts`, "rt_" + sfx, waiterT,
      { id: 777, sum: 5000, profit: 3000, payment: "Наличные", status: "Продажа" }) === 200,
      "B · Правила", "Официант создаёт чек → РАЗРЕШЕНО", "receipts.create");
    // официант создаёт товар (меню) → запрет
    ok(await fsCreate(`cafes/${cafeId}/products`, "pw_" + sfx, waiterT, { id: 9, name: "X", price: 1 }) === 403,
      "B · Правила", "Официант создаёт товар (меню) → ЗАПРЕЩЕНО", "products.write=canMenu");
    // повар создаёт товар → разрешено
    ok(await fsCreate(`cafes/${cafeId}/products`, "pc_" + sfx, cookT, { id: 10, name: "Латте", price: 18000 }) === 200,
      "B · Правила", "Повар создаёт товар (меню) → РАЗРЕШЕНО", "canMenu");
    // официант создаёт сотрудника → запрет
    ok(await fsCreate(`cafes/${cafeId}/employees`, "ew_" + sfx, waiterT, { id: 99, uid: "x", name: "X", role: "Официант" }) === 403,
      "B · Правила", "Официант создаёт сотрудника → ЗАПРЕЩЕНО", "employees.create=canManage");
    // чужой создаёт чек → запрет (не член)
    ok(await fsCreate(`cafes/${cafeId}/receipts`, "ro_" + sfx, outT, { id: 1, sum: 1 }) === 403,
      "B · Правила", "Чужой аккаунт создаёт чек → ЗАПРЕЩЕНО", "isMember=false");
    // менеджер меняет ownerUid заведения → запрет (заморожено)
    ok(await fsPatch(`cafes/${cafeId}`, mgrT, { ownerUid: mgrU }, ["ownerUid"]) === 403,
      "B · Правила", "Менеджер меняет владельца заведения → ЗАПРЕЩЕНО (tenant takeover)", "unchanged(ownerUid)");
    // менеджер меняет название заведения → разрешено
    ok(await fsPatch(`cafes/${cafeId}`, mgrT, { spot: "E2E-2" }, ["spot"]) === 200,
      "B · Правила", "Менеджер меняет настройки заведения → РАЗРЕШЕНО", "canManage");

    // ── C. ПОДПИСКА (gate) ──
    await cafeRef.update({ paidUntil: Timestamp.fromDate(new Date(Date.now() - 864e5)), createdAt: Timestamp.fromDate(new Date(Date.now() - 30 * 864e5)) }); // просрочить (и триал: createdAt в прошлое)
    ok(await fsCreate(`cafes/${cafeId}/receipts`, "rx_" + sfx, waiterT, { id: 888, sum: 1, status: "Продажа" }) === 403,
      "C · Подписка", "Просроченная подписка → чек ЗАПРЕЩЁН (серверный gate)", "subActive=false");
    await cafeRef.update({ paidUntil: Timestamp.fromDate(new Date(Date.now() + 30 * 864e5)) }); // вернуть
    ok(await fsCreate(`cafes/${cafeId}/receipts`, "ry_" + sfx, waiterT, { id: 889, sum: 1, status: "Продажа" }) === 200,
      "C · Подписка", "После оплаты → чек снова РАЗРЕШЁН", "subActive=true");

    // ── D. deleteAccount (реальный CF) + очистка ──
    const da = await callFn("deleteAccount", ownerT, {});
    ok(da.status === 200, "D · Функции", "deleteAccount (владелец) удаляет заведение целиком", `HTTP ${da.status}`);
    const gone = !(await cafeRef.get()).exists;
    ok(gone, "D · Функции", "  → заведение и все данные удалены", gone ? "cafe удалён" : "ЕЩЁ ЕСТЬ");
    if (gone) { add("Очистка", "Очистка через deleteAccount", "pass", "выполнено"); }
  } catch (e) {
    add("Ошибка", "E2E-прогон", "fail", String(e && e.message || e));
  } finally {
    // Fallback tozalash: qolgan auth userlar + kafe (deleteAccount ishlamagan bo'lsa).
    for (const uid of created) { try { await auth.deleteUser(uid); } catch (_) {} }
    try { if ((await cafeRef.get()).exists) { await db.recursiveDelete(cafeRef); add("Очистка", "Fallback-очистка заведения", "pass", "recursiveDelete"); } }
    catch (_) {}
  }

  const pass = R.filter((r) => r.status === "pass").length;
  const fail = R.filter((r) => r.status === "fail").length;
  return { results: R, summary: { total: R.length, pass, fail }, ms: Date.now() - t0, at: Date.now() };
});
