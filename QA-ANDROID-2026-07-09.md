# Xposter (Android) — qurilmada E2E test hisoboti

**Sana:** 2026-07-09 · **Qurilma:** Samsung SM-T865 (Galaxy Tab S6), Android 12, arm64-v8a, 1600×2560
**Build:** `flutter build apk --release --target-platform android-arm64` (20.5 MB), release-signed
**Test hisobi:** `qa.test.20260709@xposter.uz` / `Xq2026Test` → Firebase'da yangi kafe **«QA Test Kafe»**

---

## 1. Windows seansi Android'ni buzganmi?

**Yo'q.** `posterwin/app` — `buxoro_pos`ning alohida nusxasi (fork). So'nggi 36 soatda
`buxoro_pos/` ichida faqat **`firestore.rules`** o'zgargan (Firebase deploy fayli, APK'ga kirmaydi).
Dart manbalari tegilmagan. `flutter analyze` — **0 xato**.

---

## 2. Uchdan-uchgacha sinovdan o'tgan oqim

Registratsiya (provisioning + seed) → Menyu: kategoriya + tovar (себестоимость 2 000 + наценка 150% = **5 000** ✔)
→ Kassa: zal → Стол 1 (4 mehmon) → 2 × Choy = 10 000 → naqd 20 000 → **Сдача 10 000** ✔
→ Chek ekrani → Bosh sahifa (выручка 10 000, прибыль 6 000 ✔) → Склад → Финансы (Денежный ящик +10 000 ✔)
→ Статистика → **ilovani o'chirib qayta ochish → ma'lumot Firestore'dan tiklandi** ✔ → FCM push banner ✔

Logcat'da crash / exception **yo'q**.

---

## 3. Topilgan va TUZATILGAN xatolar

| # | Xato | Fayl | Tuzatish |
|---|------|------|----------|
| 1 | **Chek ziddiyatli:** `Наличными 10 000` + `Сдача 10 000` (mijoz 20 000 bergan) | `kassa/payment_screen.dart:137` | Chekda naqd = **berilgan** summa. Endi `Итого 10 000 · Наличными 20 000 · Сдача 10 000`. Kassa yashigi hisobi avvalgidek sof summani oladi (o'zgarmadi). |
| 2 | **Kassada tovar kartochkasi torayib qoladi**, `×N` nishoni katak chetida osilib qoladi (qisqa nomli tovarda) | `kassa/kassa_screen.dart:398` | `Stack(fit: StackFit.expand)` — kartochka katakni to'liq egallaydi. |
| 3 | **«Оплаты» hisoboti soxta:** oxirgi 6 kun hardcode nol massivdan, naqd/karta 60%/40% taxmin bilan | `stats/stats_screen.dart:941` | Haqiqiy `receiptsArchive` dan kun bo'yicha hisoblanadi. Aralash to'lovlar taqsimlanmaydi (summalar chekda saqlanmagan). |
| 4 | **Haftalik grafik doim `млн сум`** — 10 000 сум `0,0` ko'rinardi | `stats/stats_screen.dart:320` | Birlik maksimumga qarab: `сум / тыс сум / млн сум`. |
| 5 | **Registratsiyada PIN maydoni** ixtiyoriy matn qabul qiladi (test'da `qa.test...@xposter.uz` kirdi), 4 belgi cheklovi yo'q | `auth/login_screen.dart:379` | `FilteringTextInputFormatter.digitsOnly` + `LengthLimitingTextInputFormatter(4)`. |
| 6 | **Versiya nomuvofiq:** ekranda `v1.0.2`, `pubspec.yaml` da `1.0.3+4` | `more_screen.dart:88` | `v1.0.3` ga tenglashtirildi + izoh. |

Qo'shimcha: analyzer ogohlantirishlari **24 → 18** (o'lik `_hourVals`, `_dayVals`, `app_stateMonth`
konstantalari va keraksiz `!` operatori olib tashlandi).

Har bir tuzatish **qayta yig'ilib, qurilmada tasdiqlandi** (chek, kartochka, grafik, «Оплаты» jadvali).

---

## 4. Qolgan kamchiliklar (tuzatilmadi — qaror kerak)

| Muhimlik | Kamchilik | Izoh |
|---|---|---|
| 🟠 O'rta | **«Гости» / «Посетители» — mehmonlar emas, cheklar sonini sanaydi** | `Receipt` modelida `guests` maydoni yo'q. Stol 4 mehmon bilan ochilgan, statistikada «Гости 1» chiqdi. Data-model o'zgarishi kerak (Firestore migratsiyasi). |
| 🟡 Kichik | Menyu bo'sh holatida `+` bosilsa — **«Новая категория»** ochiladi, matn esa «добавьте первый товар» deydi | Oqim to'g'ri (avval kategoriya kerak), matn chalg'ituvchi. |
| 🟡 Kichik | Складda chiplar qatori `+` tugmasi ostiga kirib ketadi («Поставщики» kesilgan) | Kosmetik. |
| 🟡 Kichik | Финансы: `Расход −0` (`−` ortiqcha), Bosh sahifa: kechagi 0 bo'lsa `+0%` | Kosmetik. |
| 🟡 Kichik | `menu_screen.dart` da o'lik kod: `_emojiTile`, `_kRecipes` | Analyzer warning. |
| ⚪ Ma'lum | Ochiq stollar (`openOrders`) hali xotirada — restartda yo'qoladi | AUDIT: Faza 6. |
| ⚪ Ma'lum | App Check yoqilmagan, email tasdiqlash majburiy emas, admin-parol gating ishlamaydi | AUDIT: SZ-8, K-9. |

---

## 5. Production uchun eslatmalar

- Release APK **faqat arm64** uchun yig'ilyapti (32-bit AOT kompilyator qulaydi — antivirus/engine).
  Google Play uchun bu yetarli.
- Test kafe **«QA Test Kafe»** Firebase'da qoldi — kerak bo'lmasa Firestore'dan (`cafes/…`) va
  Auth'dan (`qa.test.20260709@xposter.uz`) o'chiring.
- Sinov davomida qurilmada animatsiyalar o'chirildi:
  `adb shell settings put global window_animation_scale 1` (va `transition_`, `animator_duration_`) bilan qaytaring.
