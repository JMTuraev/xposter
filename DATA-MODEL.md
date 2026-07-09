# Buxoro POS — Firestore ma'lumotlar modeli (yakuniy)

Backend Faza 4 amalga oshirildi (BACKEND-TAYYORGARLIK.md §9/§12 asosida).
Multi-tenant: bitta **owner** → ko'p **cafe**; har kafe o'z subkolleksiyalari bilan.

## Kolleksiyalar

```
owners/{ownerUid}
  { email, name, createdAt }

cafes/{cafeId}
  { ownerUid, name, spot, address, currency, timezone, trialEndsAt,
    serviceFeePct,
    loyalty: { earnPct, welcome, maxPayPct },
    cashShiftsEnabled,
    subscription: { status: 'trial|active|past_due|canceled', nextBilling } }

cafes/{cafeId}/employees/{uid}      # docId = Firebase Auth uid
  { id, uid, name, role, pin, phone, login, active, revenue, checks, lastLogin, createdAt }

cafes/{cafeId}/categories/{id}      { id, name, color, hidden }
cafes/{cafeId}/products/{id}        { id, name, categoryId, type, workshop, price, cost,
                                      photo, imagePath, modifications[], recipe[], noDiscount, byWeight }
cafes/{cafeId}/ingredients/{id}     { id, name, unit, stock, costPerUnit, limit }
cafes/{cafeId}/suppliers/{id}       { id, name, phone, suppliesCount, suppliesSum, debt }
cafes/{cafeId}/clientGroups/{id}    { id, name, type, percent }
cafes/{cafeId}/clients/{id}         { id, name, phone, group, card, totalSpent, bonus,
                                      birthday, gender, email, comment, address }
cafes/{cafeId}/accounts/{id}        { id, name, type, balance }         # id=1 Денежный ящик, id=2 Расчетный счет
cafes/{cafeId}/transactions/{id}    { id, date, type, category, comment, amount, account, createdAt }
cafes/{cafeId}/receipts/{id}        { id, time, waiter, sum, payment, items, profit, status, createdAt }
cafes/{cafeId}/supplies/{id}        { id, date, supplier, storage, items, sum, debt, status }
cafes/{cafeId}/storages/{id}        { id, name, sum }
cafes/{cafeId}/wastes/{autoId}      { date, storage, items, sum, employee, reason, comment }
cafes/{cafeId}/processings/{autoId} { date, from, fromQty, fromUnit, to, toQty, toUnit }
cafes/{cafeId}/inventories/{autoId} { ... }
cafes/{cafeId}/promotions/{id}      { ... }
cafes/{cafeId}/halls/{id}           { id, name }
cafes/{cafeId}/tables/{id}          { id, hallId, name, seats }
cafes/{cafeId}/stats/{YYYY-MM-DD}   { date, revenue, profit, checks, avgCheck, byHour[24],
                                      paymentMethods{}, updatedAt }   # Cloud Function yozadi (§4)
```

## Manba vs hosila (§4)
- **Manba (saqlanadi):** receipts, transactions, supplies, wastes, processings, ingredient.stock,
  account.balance, client.totalSpent/bonus, employee.revenue/checks.
- **Hosila (qayta hisoblanadi):** stats/{date} — `dailyAggregate` Cloud Function har kuni yozadi.

## Rollar (RBAC — §3)
Владелец, Управляющий, Администратор зала, Официант, Повар, Маркетолог.
Security Rules: `cafes/{cafeId}/employees/{uid}.role` bo'yicha (Firestore rules ichida `get()`).

## Indekslar (firestore.indexes.json)
- `employees.uid` — COLLECTION_GROUP (login'da xodim kafesini topish uchun).
- `receipts (status, createdAt desc)`, `transactions (account, createdAt desc)` — hisobotlar uchun.
