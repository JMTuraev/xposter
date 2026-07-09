# Promptlardan foydalanish qo'llanmasi

## Tartib (Claude.ai / Claude Design'da)
1. **Yangi suhbat oching** (claude.ai) — model: Sonnet yoki Opus, Artifacts yoqilgan bo'lsin. Yaxshisi: Project yaratib, ichiga `mock-data.json` va `design-system.md` ni ham yuklang (shart emas, promptlarda hammasi bor).
2. `00-MASTER-PROMPT.md` ichidagi promptni (--- chiziqlar orasini) to'liq nusxalab yuboring → Claude telefon ramkali karkas + Bosh sahifani quradi.
3. Natijani ko'rib chiqing. Xato/istak bo'lsa shu zahoti yozing («tugma kattaroq», «grafik chiroyliroq» ...). Qoniqqach:
4. `01-KASSA-TERMINAL.md` → yuboring. Keyin `02-MENU-SKLAD.md` → `03-STATISTIKA-FINANSY.md` → `04-MARKETING-SOTRUDNIKI-NASTROYKI.md`.
5. Har qadamdan keyin sinang: tugmalar bosilsin, formalar saqlansin, toastlar chiqsin.

## Maslahatlar
- Bitta qadam natijasi katta bo'lsa va Claude «davom etaymi?» desa — «davom et» deng; artifact uzilib qolsa «shu joyidan davom ettir» deng.
- Suhbat juda uzayib ketsa: yangi suhbat ochib, oxirgi artifact kodini + keyingi promptni birga yuboring («мана мавжуд прототип, шу промптни бажар»).
- Dizaynni buzmasligini nazorat qiling: ko'k/binafsha rang paydo bo'lsa — «Claude Light palitradan chiqma» deb eslating.
- Prototip tayyor bo'lgach undan Flutter'ga o'tish: har ekran screenshotini + shu audit fayllarini Flutter-loyihaga spetsifikatsiya sifatida ishlating. Ma'lumotlar modeli `mock-data.json` tuzilmasi bo'yicha Firestore kolleksiyalariga o'tadi (products, ingredients, orders, transactions, clients, employees, supplies...).

## Firebase eslatmasi (2-bosqich uchun)
- Auth: telefon/email (Владелец) + PIN lokal (kassirlar uchun ilova ichida)
- Firestore: `accounts/{accId}/products|ingredients|orders|receipts|transactions|clients|employees|supplies|wastes|inventories|settings`
- Offline-first: Firestore persistence + kassa navbati (pending writes)
- Storage: mahsulot rasmlari; FCM: yangi buyurtma push; Functions: statistika agregatlari (kunlik revenue/profit)
