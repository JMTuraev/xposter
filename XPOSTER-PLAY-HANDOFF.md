# Xposter — Google Play'ga chiqarish: HOLAT va QOLGAN QADAMLAR

Sana: 2026-07-07

## ✅ Bajarilgan ishlar

### 1. Ilova (release AAB) yig'ildi
- Fayl: `D:\poster\buxoro_pos\build\app\outputs\bundle\release\app-release.aab` (~20 MB)
- **Muhim:** release AOT kompilyatori 32-bitli ARM (`android-arm`) uchun qulab tushardi
  (xato kodi `-1073741819` = 0xC0000005, ehtimol McAfee antivirusi yoki buzilgan
  Flutter engine artefakti sabab). Shu sababli **faqat arm64** uchun yig'ildi
  (`flutter build appbundle --release --target-platform android-arm64`).
  Google Play baribir 64-bit talab qiladi, shuning uchun bu to'g'ri va yetarli.
  (Agar 32-bit qurilmalarni ham qo'llab-quvvatlash kerak bo'lsa — antivirusda
  loyiha papkasini istisno qiling yoki Flutter'ni yangilang, keyin to'liq yig'ing.)

### 2. Upload keystore yaratildi va imzolash sozlandi
- Keystore: `D:\poster\buxoro_pos\android\app\upload-keystore.jks`
- **Parollar va ma'lumotlar: `D:\poster\KEYSTORE-INFO.txt`**
- ⚠️ **JUDA MUHIM: `KEYSTORE-INFO.txt` va `upload-keystore.jks` ni xavfsiz joyda
  saqlang va ZAXIRA nusxa oling.** Bu yo'qolsa, ilovaga yangilanish chiqara olmaysiz.
- `android/key.properties` va `android/app/build.gradle.kts` imzolash uchun sozlandi.

### 3. Firebase Hosting'da Maxfiylik siyosati joylashtirildi
- URL: **https://poster-ae945.web.app/privacy.html**
- Bu URL Play Console'da Privacy policy, Data safety (account & data deletion) uchun ishlatildi.

### 4. Google Play Console'da "Xposter" ilovasi yaratildi
- Akkaunt: cashblackdev@gmail.com
- Package: `com.buxoropos.buxoro_pos`, til: Русский (ru-RU), App, Bepul (Free)
- **To'ldirilgan bo'limlar:**
  - ✅ Maxfiylik siyosati (Privacy policy)
  - ✅ Reklama (Ads) — reklama yo'q
  - ✅ Возрастные ограничения (Content rating / IARC) — Xarid/kontent yo'q
  - ✅ Безопасность данных (Data safety) — Email, User ID, Photos; shifrlangan; o'chirish havolasi
  - ✅ Store listing MATNLARI kiritildi (qisqa + to'liq tavsif, ru-RU)

### 5. Play Store assetlari tayyorlandi — `D:\poster\play-assets\`
- `icon-512.png` — ilova belgisi (512×512)
- `feature-1024x500.png` — feature grafika (1024×500)
- `screenshots\01..07_*.png` — 7 ta telefon skrinshoti, **9:16 (1440×2560)**, har birida
  "Xposter" brend yozuvi qo'shilgan. (D:\poster'da alohida "design" papka topilmadi —
  ilovaning haqiqiy ekran tasvirlari ishlatildi; ular "Poster/Buxoro POS" kabi raqobatchi
  brendni ko'rsatmaydi, shunchaki demo biznes "Чайхана Бухоро" ko'rinadi.)

---

## ⛔ QOLGAN QADAMLAR (siz bajarishingiz kerak — vosita cheklovlari sabab)

### A) AAB'ni Internal testing'ga yuklash
Sabab: AAB 20 MB, brauzer ko'prigi orqali yuklash chegarasi 10 MB; native fayl
oynasini avtomatlashtirish (Chrome "faqat ko'rish" rejimida) mumkin emas.
1. Play Console → Xposter → **Тестирование и выпуск → Внутреннее тестирование → Создать выпуск**
2. "Наборы App Bundle" → **Загрузить** (yoki faylni sudrab tashlang):
   `D:\poster\buxoro_pos\build\app\outputs\bundle\release\app-release.aab`
3. "Название выпуска" avtomatik to'ladi; **Далее → Сохранить**.

### B) Store listing rasmlarini biriktirish
Sabab: Play'ning media tanlash oynasi (iframe) "Добавить" tugmasi avtomatlashtirishga
yetib bo'lmaydigan joyda. Fayllar tayyor — 3 marta bosish kifoya:
1. Store listing → **Значок**: `D:\poster\play-assets\icon-512.png`
2. **Картинка для описания (feature)**: `D:\poster\play-assets\feature-1024x500.png`
3. **Скриншоты для смартфона**: `D:\poster\play-assets\screenshots\` ichidagi 01–07 (kamida 4 ta)
4. **Сохранить**.

### C) "Учетные данные" (App access) — test login
Sabab: ilova Firebase Auth bilan himoyalangan; Google reviewerlar o'zi akkaunt
yarata olmaydi. Sizdan ishlaydigan **test email/parol** kerak (men akkaunt yarata olmayman).
1. Store listing yonidagi **Контент приложения → Учетные данные → "Да"**
2. Bo'lim nomi, test login/parol va ko'rsatmalarni kiriting → Сохранить.
3. Shundan so'ng **Целевая аудитория** (target audience) bo'limini ham to'ldiring.

### D) Yakuniy yuborish
Barcha bo'limlar yashil bo'lgach: **Обзор публикации → Отправить на проверку**.

---

## Fayllar joylashuvi (qisqacha)
- AAB: `D:\poster\buxoro_pos\build\app\outputs\bundle\release\app-release.aab`
- Keystore + parollar: `D:\poster\KEYSTORE-INFO.txt`  ← ZAXIRA OLING
- Assetlar: `D:\poster\play-assets\`
- Maxfiylik siyosati: https://poster-ae945.web.app/privacy.html
- Qayta yig'ish skripti: `D:\poster\buxoro_pos\BUILD-ARM64.bat`
