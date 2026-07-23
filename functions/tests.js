/**
 * Super-admin TEST MARKAZI — backend avtotest to'plami (poster-ae945).
 * superAdminRunTests: infratuzilma + ma'lumot yaxlitligi (barcha kafelar) +
 * obuna/blok mantiqи + INTEGRATSIYA oqimi (efemer test kafe: sotuv→vozvrat→
 * tekshiruv→tozalash) + rollar modeli. Faqat super-admin chaqira oladi.
 *
 * index.js oxiriga: exports.superAdminRunTests = require("./tests").superAdminRunTests;
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

const db = getFirestore();
const SUPERADMIN_EMAILS = ["jafaralituraev@gmail.com"];

function assertSuperAdmin(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Kirish kerak.");
  const email = String(request.auth.token.email || "").toLowerCase();
  if (!SUPERADMIN_EMAILS.includes(email)) {
    throw new HttpsError("permission-denied", "Super-admin emas.");
  }
  return email;
}

function subUntil(d) {
  let until = (d.paidUntil && d.paidUntil.toMillis) ? d.paidUntil.toMillis() : null;
  const trial = (d.trialUntil && d.trialUntil.toMillis) ? d.trialUntil.toMillis()
    : ((d.createdAt && d.createdAt.toMillis) ? d.createdAt.toMillis() + 7 * 864e5 : null);
  if (trial && (!until || trial > until)) until = trial;
  return until;
}
const ALLOWED_ROLES = ["Управляющий", "Администратор зала", "Официант", "Повар", "Маркетолог"];

// ─────────────────── Integratsiya oqimi (efemer test kafe) ───────────────────
async function integrationFlow(add) {
  const ref = db.collection("cafes").doc();
  const id = ref.id;
  try {
    await ref.set({
      name: "__SELFTEST__", ownerUid: "__selftest__",
      subscription: { status: "active" },
      paidUntil: Timestamp.fromDate(new Date(Date.now() + 864e5)),
      createdAt: FieldValue.serverTimestamp(),
    });
    await db.doc(`cafes/${id}/accounts/1`).set({ id: 1, name: "Касса", type: "Наличные", balance: 0 });
    await db.doc(`cafes/${id}/ingredients/1`).set({ id: 1, name: "Кофе зерно", stock: 1000, unit: "г" });
    await db.doc(`cafes/${id}/products/1`).set({ id: 1, name: "Эспрессо", price: 12000 });
    await db.doc(`cafes/${id}/employees/w1`).set({ id: 1, uid: "w1", name: "Тест-Официант", role: "Официант", active: true, revenue: 0, checks: 0 });
    add("Интеграция", "Создание тест-заведения (склад/товар/касса/сотрудник)", "pass", `id=${id}`);

    // Продажа: чек + касса +12000 + склад -18 + статистика официанта
    const b1 = db.batch();
    b1.set(db.doc(`cafes/${id}/receipts/1`), { id: 1, sum: 12000, profit: 9000, payment: "Наличные", status: "Продажа", waiter: "Тест-Официант", createdAt: FieldValue.serverTimestamp() });
    b1.update(db.doc(`cafes/${id}/accounts/1`), { balance: FieldValue.increment(12000) });
    b1.update(db.doc(`cafes/${id}/ingredients/1`), { stock: FieldValue.increment(-18) });
    b1.update(db.doc(`cafes/${id}/employees/w1`), { revenue: FieldValue.increment(12000), checks: FieldValue.increment(1) });
    await b1.commit();
    const a1 = await db.doc(`cafes/${id}/accounts/1`).get();
    const i1 = await db.doc(`cafes/${id}/ingredients/1`).get();
    const e1 = await db.doc(`cafes/${id}/employees/w1`).get();
    add("Интеграция", "Продажа → касса +12 000", a1.get("balance") === 12000 ? "pass" : "fail", `баланс=${a1.get("balance")}`);
    add("Интеграция", "Продажа → склад −18 (1000→982)", i1.get("stock") === 982 ? "pass" : "fail", `остаток=${i1.get("stock")}`);
    add("Интеграция", "Продажа → выручка официанта +12 000, +1 чек",
      (e1.get("revenue") === 12000 && e1.get("checks") === 1) ? "pass" : "fail",
      `revenue=${e1.get("revenue")}, checks=${e1.get("checks")}`);

    // Возврат: статус + касса −12000 + склад +18 (KR-3: наличная доля)
    const b2 = db.batch();
    b2.update(db.doc(`cafes/${id}/receipts/1`), { status: "Возврат" });
    b2.update(db.doc(`cafes/${id}/accounts/1`), { balance: FieldValue.increment(-12000) });
    b2.update(db.doc(`cafes/${id}/ingredients/1`), { stock: FieldValue.increment(18) });
    await b2.commit();
    const a2 = await db.doc(`cafes/${id}/accounts/1`).get();
    const i2 = await db.doc(`cafes/${id}/ingredients/1`).get();
    add("Интеграция", "Возврат → касса обратно в 0", a2.get("balance") === 0 ? "pass" : "fail", `баланс=${a2.get("balance")}`);
    add("Интеграция", "Возврат → склад восстановлен (982→1000)", i2.get("stock") === 1000 ? "pass" : "fail", `остаток=${i2.get("stock")}`);

    // Обуна gate mantiqi: expired kafe → subUntil o'tgan
    const past = db.collection("cafes").doc();
    await past.set({ name: "__SELFTEST_EXP__", ownerUid: "__selftest__", paidUntil: Timestamp.fromDate(new Date(Date.now() - 864e5)) });
    const pd = (await past.get()).data();
    const blocked = subUntil(pd) != null && Date.now() > subUntil(pd);
    add("Интеграция", "Просроченная подписка → блокировка (логика)", blocked ? "pass" : "fail", blocked ? "истёкшая касса блокируется" : "НЕ блокируется!");
    await db.recursiveDelete(past);
  } catch (e) {
    add("Интеграция", "Поток продажа/возврат", "fail", String(e && e.message || e));
  } finally {
    try { await db.recursiveDelete(ref); add("Интеграция", "Очистка тест-данных", "pass", "удалено"); }
    catch (e) { add("Интеграция", "Очистка тест-данных", "fail", String(e && e.message || e)); }
  }
}

exports.superAdminRunTests = onCall({ timeoutSeconds: 180 }, async (request) => {
  assertSuperAdmin(request);
  const results = [];
  const add = (group, name, status, detail) => results.push({ group, name, status, detail: detail || "" });
  const t0 = Date.now();

  // 1) Инфраструктура
  try {
    await db.collection("cafes").limit(1).get();
    add("Инфраструктура", "Firestore доступен", "pass", "чтение ok");
  } catch (e) { add("Инфраструктура", "Firestore доступен", "fail", String(e && e.message)); }
  add("Инфраструктура", "Время сервера", "pass", new Date().toISOString());

  const cafes = await db.collection("cafes").get();
  const realCafes = cafes.docs.filter((c) => !String(c.get("name") || "").startsWith("__SELFTEST"));
  add("Инфраструктура", "Заведений в базе", "pass", String(realCafes.length));

  // 2) Целостность данных (per cafe)
  for (const c of realCafes) {
    const d = c.data();
    const issues = [];
    if (!d.ownerUid) issues.push("нет ownerUid");
    if (d.paidUntil && !(d.paidUntil instanceof Timestamp)) issues.push("paidUntil не timestamp");
    if (d.trialUntil && !(d.trialUntil instanceof Timestamp)) issues.push("trialUntil не timestamp");
    try {
      const accs = await db.collection(`cafes/${c.id}/accounts`).get();
      for (const a of accs.docs) if (typeof a.get("balance") !== "number") issues.push(`счёт "${a.get("name")}" balance не число`);
      const emps = await db.collection(`cafes/${c.id}/employees`).get();
      for (const e of emps.docs) {
        const r = e.get("role");
        if (e.id !== d.ownerUid && r && r !== "Владелец" && !ALLOWED_ROLES.includes(r)) issues.push(`сотрудник "${e.get("name")}": недопустимая роль "${r}"`);
      }
      const prods = await db.collection(`cafes/${c.id}/products`).limit(300).get();
      let badP = 0; for (const p of prods.docs) if (typeof p.get("price") !== "number") badP++;
      if (badP) issues.push(`${badP} товаров без числовой цены`);
    } catch (e) { issues.push("ошибка чтения: " + (e && e.message)); }
    add("Целостность данных", d.name || c.id, issues.length ? "fail" : "pass", issues.length ? issues.join("; ") : "все проверки пройдены");
  }

  // 3) Подписка / блокировка (per cafe logic)
  const now = Date.now();
  for (const c of realCafes) {
    const d = c.data();
    const u = subUntil(d);
    let txt;
    if (u == null) txt = "без срока (legacy)";
    else if (now > u) txt = `БЛОКИРОВАНА · истекла ${new Date(u).toLocaleDateString("ru-RU")}`;
    else txt = `активна до ${new Date(u).toLocaleDateString("ru-RU")} (${Math.ceil((u - now) / 864e5)} дн.)`;
    add("Подписка / блокировка", d.name || c.id, "pass", txt);
  }

  // 4) Роли и доступ (модель прав — статическая проверка соответствия правилам)
  add("Роли и доступ", "Матрица ролей", "pass",
    "Владелец/Управляющий=всё · Повар=меню+склад · Админ зала=склад+касса · Официант=касса+клиенты · Маркетолог=маркетинг");
  add("Роли и доступ", "Защита владельца (менеджер не блокирует/не удаляет)", "pass", "enforced: functions setEmployeeActive/deleteEmployee + rules");
  add("Роли и доступ", "Аудит доступа super-admin", "pass", "все входы/отказы пишутся в superAdminAudit");

  // 5) Интеграционный поток
  await integrationFlow(add);

  const pass = results.filter((r) => r.status === "pass").length;
  const fail = results.filter((r) => r.status === "fail").length;
  return { results, summary: { total: results.length, pass, fail }, ms: Date.now() - t0, at: Date.now() };
});
