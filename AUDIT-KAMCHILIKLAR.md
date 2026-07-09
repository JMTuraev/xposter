# Buxoro POS — Prototip kamchiliklari bo'yicha to'liq audit

## ⚡ FAZA 5 — 2026-07-08: Qurilmada to'liq E2E audit + KRITIK fixlar (Claude Code, Samsung A57)

**Metod:** Ilova real qurilmada odam kabi ishlatildi (registratsiya → menyu → savdo → to'lov → restart → PIN → xodim yaratish), har xato joyida tuzatildi va qayta tekshirildi.

### 🔴 Topilgan va TUZATILGAN kritik xatolar
| # | Xato | Tuzatish |
|---|---|---|
| 1 | **Firestore rules: login umuman ishlamaydi** — `cafes.where(ownerUid==uid)` query `PERMISSION_DENIED` (get()-ga asoslangan isOwner list-so'rovda isbotlanmaydi); xodim logini uchun collectionGroup rule umuman yo'q | `firestore.rules` tuzatildi (resource.data orqali + collection-group employees rule). **DEPLOY KUTILMOQDA** (quyida). Klientda workaround: owner doc'ga `cafeId` yoziladi — yangi akkauntlar eski rules bilan ham ishlaydi |
| 2 | **Savdo Firestore'ga HECH QACHON yozilmagan** — completePayment tranzaksiyasida yozuvdan keyin o'qish (`Transactions require all reads before writes` assert, jimgina yutilardi) | Tranzaksiya qayta yozildi: avval barcha get, keyin yozuvlar; xato bo'lsa fallback saveReceipt + debugPrint |
| 3 | **Kategoriya yaratish/o'chirish, tovar/ingredient o'chirish/tahrirlash Firestore'ga yozilmasdi** (menu_screen to'g'ridan-to'g'ri list mutatsiyasi) — restartda hammasi qaytib kelardi/yo'qolardi | Barcha joylar AppState write-through metodlariga o'tkazildi (addCategory/removeCategory/saveProduct/removeProduct/removeIngredient/removeClient/addClientGroup/addSupplier/addSupplyRaw/saveWasteRaw…) |
| 4 | **Statistika restartda nolga tushardi** (salesToday/grafik/то'lov usullari faqat xotirada) | `AppState.recomputeStatsFromReceipts()` — receipts snapshot kelganda arxivdan qayta hisoblanadi; Receipt'ga `createdAt` (server timestamp) qo'shildi |
| 5 | **Chek raqami har sessiyada №1 dan** — Firestore'da eski chek ustiga yozilardi | KassaController `_syncNextOrder()` — arxiv max id + 1 |
| 6 | **Kassa «Меню пусто» deb yolg'on ko'rsatardi** — tovar bor, lekin kategoriyasiz bo'lsa kassada sotib bo'lmasdi | Kategoriya yo'q → tovarlar to'g'ridan-to'g'ri; kategoriyasiz tovarlar uchun «Прочее» plitkasi |
| 7 | **Auth UX butunlay xom edi:** login sahifasida oldindan yozilgan test parol, demo PIN ro'yxati, soxta «Клиентский номер 567053», ishlamaydigan «Войти по PIN», loading holati yo'q, «lip» effekti (sessiya tiklanayotganda login formasi ko'rinardi) | Login ekrani qayta yozildi: toza forma, «Забыли пароль?» (real reset email), busy-spinner, splash ekran (`bootstrapping`), PIN faqat qulflangan holatda, register validatsiyasi (email regex, PIN 4 raqam, parol ko'z tugmasi) |
| 8 | **Kassadagi 🔒 to'liq logout qilardi** (Firebase sessiya o'chib, e-mail/parol qayta so'ralardi) | `AppState.lock()` — sessiya saqlanadi, PIN bilan qaytish |
| 9 | **Brend chalkash** — Play'da «Xposter», ilovada «Buxoro POS», cheklarda «Чайхана „Бухоро“» hardcode | Hamma joyda Xposter + kafe nomi dinamik (chek, PIN ekran, sozlamalar, obuna, ilovalar, printer test) |
| 10 | **Soxta to'lov** — obunada karta raqami kiritib «Оплачено! 🎉» chiqarardi (hech narsa bo'lmasdan) | Halol versiya: «onlayn to'lov tez orada, biz bilan bog'laning» sheet |
| 11 | Trial banner/hisoblar hardcode «до 9 июля» | `trialEndsAt`dan dinamik (yangi kafe: +14 kun) |
| 12 | Vozvrat Firestore'ga yozilmasdi (status/kassa/kassir) | saveReceipt + saveAccount + saveEmployee write-through |
| 13 | Sozlamalar «Компания» save = toast qobiq | Nom+manzil real saqlanadi (setCompany → Firestore); «Процент за обслуживание» real serviceFeePct bilan bog'landi; «ID заведения» ko'rsatiladi |
| 14 | To'lovda «Напечатать чек» printer sozlanmagan holda ham yoniq (to'lovdan keyin xato) | Printer saqlanmagan bo'lsa default o'chiq |
| 15 | Registratsiyada yangi kafega zal/stol seed yo'q (kassa bo'm-bo'sh) | Provision: «Основной зал» + 4 stol seed |
| 16 | Menyu bo'sh holati «Ничего не найдено — измените запрос» (yangi foydalanuvchi uchun chalg'ituvchi) | «В меню пока пусто — нажмите +» |

### ✅ Qurilmada tasdiqlangan E2E oqimlar (Samsung A57, yangi akkaunt bilan)
Registratsiya (provisioning+seed) → kategoriya/tovar yaratish (persist) → zal xaritasi → stol ochish (mehmonlar) → savdo (naqd) → chek ko'rinishi (dinamik kafe nomi) → **restart → statistika/mahsulotlar/kassa yashigi (35 000) Firestore'dan tiklandi** → kassa qulflash → PIN bilan qaytish → xodim yaratish (Cloud Function `createEmployee` ishladi) → parol tiklash dialogi → noto'g'ri parol xabari.

### ⛔ FOYDALANUVCHI QILISHI KERAK
1. **Rules deploy (majburiy!):** `cd D:\poster\buxoro_pos && firebase deploy --only firestore:rules --project poster-ae945` — busiz eski akkauntlar va xodim logini kirolmaydi.
2. Yangi AAB (v1.0.2+3) Play'ga yuklash: `build\app\outputs\bundle\release\app-release.aab`.

### ⚡ FAZA 5.1 — o'sha kun, 2-sessiya (Galaxy Tab S6 bilan davomi)
Qolgan barcha persist bo'shliqlari yopildi va planshetda tekshirildi:
| # | Nima qilindi | Tekshiruv |
|---|---|---|
| 17 | **Aksiyalar (promotions)** endi Firestore'da (id bilan, listener orqali qaytadi) | kod |
| 18 | **Inventarizatsiya** hujjatlari persist + «Провести»da skorrektirlangan qoldiqlar ham endi Firestore'ga yoziladi (ilgari yozilmasdi!) | kod |
| 19 | **lastLogin** endi saqlanadi (merge, PIN buzilmaydi) | планшет: «вход: 08.07 12:08» ✓ |
| 20 | **Sotuv/vozvrat → Финансы→Транзакции** avtomatik yoziladi («Продажи» kategoriyasi, balansga tegmasdan — u atomik tranzaksiyada) | планшет: «Чек №2 · +35 000» ✓ |
| 21 | **Sozlamalarning QOLGAN barcha bo'limlari** (Общие/Администрирование/Заказы/Доставка/Безопасность/Чек) endi cafe.uiSettings'da saqlanadi; chekdagi demo-hardcode defaultlar (Buxoro_Guest/plov2026/Ляби-Хауз/jafar@buxoro.uz) tozalandi | kod |
| 22 | **Planshet layouti**: kassa kategoriya/tovar/stol gridlari GridView.extent — ustunlar ekranga qarab (planshetda 4+ ustun, cho'zilgan kartalar yo'q) | планшет ✓ |
| 23 | «Методы оплаты»da 0 сум bo'lsa ham «2%» ko'rinardi — haqiqiy foiz matnda, bar minimumi alohida | kod |
| 24 | Versiya matni v1.0.2 | ✓ |

**Multi-device E2E (SM-T865):** planshetga login → A57 ma'lumotlari to'liq keldi (35 000 stats, mahsulotlar, xodim aziz) → planshetda savdo → **chek №2** (raqam davomiyligi qurilmalararo!) → Денежный ящик **70 000** (ikkala qurilma jami) → Транзакциялар ro'yxatida sotuv.

### ⚡ FAZA 5.2 — o'sha kun, 3-sessiya: OWNER+STAFF (2 qurilma) + PUSH-BILDIRISHNOMALAR

**Deploy qilindi (foydalanuvchi ruxsati bilan):** yangi `firestore.rules` (login blokini ochdi) + barcha Cloud Functions + yangi `notifySale`.

| # | Nima qilindi | Tekshiruv |
|---|---|---|
| 25 | **Xodim kirishi tizimi yaratildi** — ilgari xodim UMUMAN kira olmasdi (UI yo'q edi, cafeId'ni bilish imkonsiz). Endi: 6 raqamli **«Код заведения»** (provision'da yaratiladi + eski kafelarга self-heal), `cafeCodes/{code}` ochiq mapping, login ekranida **«Я сотрудник — войти по коду»** (логин+код+пароль), Сотрудники ekranida kod kartasi | Planshetda kod 409883 ko'rindi; xodim Kassir yaratildi (Cloud Function) |
| 26 | **Push-bildirishnomalar (FCM)** — topic-model: login'da `cafe_{id}` (+owner uchun `cafe_{id}_owner`), logout'da unsubscribe; POST_NOTIFICATIONS ruxsati; foreground'da qora banner (SnackBar), background'da tizim bildirishnomasi; **Cloud Function `notifySale`**: yangi chek → owner-topic'ka push | **Jonli tasdiqlandi:** planshetda savdo → 5 soniyada «🔔 Новый чек №3 — 35 000 сум · Наличными · Jafar» banneri |
| 27 | Kod maydoni faqat raqam + 6 belgigacha (LabeledField'ga inputFormatters qo'shildi) | kod |

**Eslatma:** 2-qurilma (A57) testi davomida USB uzilib turdi — staff login jonli testi kabel qayta ulanганда yakunlandi (quyida).

### 🔜 Keyingi faza uchun qolganlar
- Ochiq stollar/cheklar (openOrders) hali xotirada — restart/ikkinchi qurilmada ko'rinmaydi (Faza 6: check serialization); App Check yoqilmagan; email verification majburlanmaydi; aziz xodimining paroli noma'lum (o'chirib qayta yaratish mumkin); Wi-Fi adb tavsiya (USB port beqaror).

---

**Sana:** 2026-07-05
**Ob'ekt:** `D:\poster\buxoro_pos` (Flutter, ~5 600 qator, 31 fayl)
**Solishtirish etaloni:** `D:\poster\audit\*.md` (Poster POS jonli audit) + real Poster POS xatti-harakati
**Metod:** Har bir modul kodini spetsifikatsiya bilan qator-qator solishtirish; asosiy da'volar `grep`/kod bilan mustaqil tasdiqlandi.

---

## 0. 🔧 TUZATISH JURNALI (Faza 1 — front qism, backend'siz)

**Yangilangan:** 2026-07-05. Quyidagilar **kodda bajarildi**; qurilma buildидан keyin yakuniy tasdiqlanadi (sandboxда `flutter` yo'q, shuning uchun `rebuild_and_install.bat` bilan qurib, `errlog.txt`ni ulashing).

| Kamchilik | Holat | Nima qilindi |
|---|---|---|
| §3.1 Login/Register yo'q | ✅ Bajarildi | Yangi `login_screen.dart` (логин/парол + PIN + Регистрация); `main.dart`ga auth gate (`_AuthGate`); ilova endi to'g'ridan egaga ochilmaydi. |
| §3.2 PIN chetlab o'tiladi | ✅ Bajarildi | PIN endi ilova darajasида (butun ilovani bloklaydi); kassadagi 🔒 → haqiqiy `logout()`. |
| §3.3 Rollar/huquqlar matritsasi | ✅ Bajarildi | `AppState.rolePermissions` + `can(perm)`; tab'lar (`root_scaffold`) va «Ещё» plitkalari (`more_screen`) ruxsatga qarab filtrlanadi. |
| §3.4 Ofitsiant/POS rolni bilmaydi | ✅ Bajarildi | 7 ta rolli seed xodim (PINlar); Официант faqat Kassa/Zal ko'radi; Повар/Маркетолог cheklangan. |
| §3.5 Zal/stol/karta зала | ✅ Bajarildi | `Hall`/`RestTable` modellari (o'rin soni); kassa ochilganda **zal xaritasi** (band/bo'sh, summa); stolga bosib chek ochish; mehmonlar soni. |
| §3.6 «Гости»/«Карта зала» toggle | ✅ Bajarildi | Zal xaritasi real; mehmonlar soni so'raladi. |
| §3.9 + «stol/zal/servis edit» | ✅ Bajarildi | Zal xaritasida: zal qo'shish/nomlash/o'chirish, stol qo'shish/tahrir/o'chirish (o'rin+zal), servis foizini alohida o'zgartirish (0/5/10/15/ixtiyoriy). |
| §3.9 Servis foizi qo'llanmaydi | ✅ Bajarildi | `CheckDoc.dueFor` endi servis foizini qo'shadi (faqat zalda); chek panelida «Обслуживание N%» qatori. |
| §3.7 Mahsulot rasmlari | ✅ Bajarildi (Faza 2) | `image_picker` qo'shildi; товар/тех.карта formasida haqiqiy rasm yuklash; menyu va kassa katalogida rasm ko'rinadi (rasm yo'q bo'lsa — emoji). |
| §3.8 Retsept→sklad | ✅ Bajarildi (Faza 2) | Tех.карта retsepti REAL ingredientlarga bog'lanadi va saqlanadi; hardcode `_kRecipes` (id-collision bug) bekor; **sotuvda ingredient qoldig'i avtomatik kamayadi**. |
| §19 Grafik statistika + vozvrat yaxlitligi | ✅ Bajarildi (Faza 2) | Sotuv `byHour`/`byWeekday`/`chartSeries`/`client.totalSpent`ни to'ldiradi (Главная grafigi jonli); vozvrat to'lov-usuli/kassa yashigi/kassir statni ham teskari qaytaradi. |
| Menyu/marketing polishi | ✅ Bajarildi (Faza 2) | Kategoriya rangini tanlash + plitkada ko'rsatish; «Дублировать» modifikatsiya/retsept/rasmни saqlaydi; mijoz formasi email/jins/izoh/adресни saqlaydi. |
| §18 sozlamalarni persist · §20 stats sahifalari (Клиенты/Цехи/Налоги) · §21 moliya (Cash flow/Зарплата) va sklad (Перемещения/Переработки) modullari · marketing loyallik/aksiya→kassa ulash | 🔜 Faza 3 | Katta modul-qo'shimchalar. Build tasdiqlangач davom etamiz (bitta test buzilmasligi uchun ataylab keyinga qoldirildi). |

**Yangi/o'zgargan fayllar (Faza 1):** `models.dart`, `state/app_state.dart`, `main.dart`, `screens/auth/login_screen.dart` (yangi), `screens/root_scaffold.dart`, `screens/more_screen.dart`, `screens/kassa/kassa_controller.dart`, `screens/kassa/kassa_screen.dart`.

**Faza 2 fayllar:** `pubspec.yaml` (+`image_picker`), `widgets/ui.dart` (+`ProductThumb`), `screens/menu/product_form.dart`, `screens/menu/menu_screen.dart`, `screens/shared/client_form.dart`, `screens/kassa/orders_screen.dart`, `models.dart`, `state/app_state.dart`, `screens/kassa/kassa_controller.dart`.

> **Build eslatmasi:** yangi paket qo'shildi (`image_picker`) — `rebuild_and_install.bat` avval `flutter pub get` ishlatishi kerak (internet talab qilinadi). Rasm demo prototипда galereyadan olinadi; backend yo'q sabab ilova qayta ishga tushganda rasm yo'li saqlanmaydi (bu Faza 3/backendда hal bo'ladi).

**Faza 2.1 — qurilma testидан keyin (Claude Code, Samsung A57, `flutter analyze` 0 error) topилган 3 bug tuzатилди:**
- ✅ **Vozvrat grafик/o'rtача chekни qaytармасди** → endi vozvrat `byHour`/`byWeekday`/`chartSeries`/`avgCheck`ни ham teskари qaytаради (`orders_screen.dart`).
- ✅ **Kvitансияда «Обслуживание» qatори yo'q edi** → `ReceiptData`га `serviceLabel/serviceAmount` qo'шилди; ekрандаги chek, ESC/POS chop (CP866+lotin zaxira) va precheck — hammаsида servis qatори chiqади (`printer_service.dart`, `payment_screen.dart`, `kassa_screen.dart`).
- ✅ **Arxив «Показано 1 из 0 чеков»** → hisoblagич endi arxивдаги jami cheklар soniни ko'рсатади (`orders_screen.dart`).

**Faza 3 — qolgan modullar (davom etmoqda):**
- ✅ **§20 Statistика:** «По времени»/«По дням» grafiklari endi real `byHour`/`byWeekday`дан; «Неделя»/«Месяц» KPI `chartSeries`дан (+nol-ga bo'lish crashi tuzatildi); yangi **Клиенты**, **Цехи**, **Налоги** sahifalari qo'shildi (`stats_screen.dart`).
- ✅ **§21 Ombor limiti:** ingredient/tovar formasида «Лимит» endi tahrirlanadi (ilgari hardcode `1`) — past-qoldiq ⚠️ ogohlantirishlari ma'noli bo'ldi (`menu_screen.dart`, `sklad_screen.dart`).
- ✅ **§21 Moliya:** **Cash flow** (kategoriya bo'yicha kirim/chiqim + chistiy poток + hisob qoldig'i) va **Зарплата** (штат по должностям) sahifalari qo'shildi (`finance_screen.dart`).
- ✅ **§21 Sklad Переработки:** yangi tab — bir ingredientni boshqasiga qayta ishlash (birini kamaytiradi, ikkinchisini oshiradi), tarix bilan (`sklad_screen.dart` + `AppState.addProcessing`).
- ✅ **Marketing loyallik → kassa:** bonus dasturi endi REAL — xariddan `bonusEarnPct`% bonus qaytadi, `maxBonusPayPct`gача bonus bilan to'lash, yangi mijozga `welcomeBonus`; Маркетинг → Лояльность → «Сохранить» endi `AppState`га yozadi (ilgari toast) (`marketing_screen.dart`, `kassa_controller.dart`, `app_state.dart`).
**Faza 3.1 — qurilma testidan keyin (Claude Code, Samsung A57, `flutter analyze` 0 error, 21 warning/info):**
- ✅ **Kassa «Клиент» tabi crash bo'lardi** (mijoz biriktirilganda qizil ekran: `Container: Cannot provide both a color and a decoration`) → `color:` `BoxDecoration` ichiga ko'chirildi (`kassa/client_tab.dart`, `_clientRow`). Tuzatishdan keyin tab ishlaydi, mijoz kartasida 💎 bonus ko'rinadi.
- ✅ Faza 3'ning 10 bandi ham qurilmada tekshirildi (statistika grafik/tablari, cash flow, zarplata, pererabotka, limit, loyallik 5% + welcome bonus) — hammasi ishlaydi. Kvitansiyada «Обслуживание 10%» qatori ham chiqadi (Faza 2.1 tuzatishi tasdiqlandi).
- ✅ **Faza 3.2 — yuqoridagi 2 kichik topilma tuzatildi** (`marketing_screen.dart`, `_clientCard`): mijoz kartasida «Покупки» endi real ma'lumot ko'rsatadi («Всего покупок на N» + to'plangan bonus), E-mail/Адрес saqlangan qiymatlar chiqadi; «Редактировать» tugmasidан ikonка olib tashlanди (RenderFlex overflow yo'q). Qolgan: sotuv Финансы→Транзакции ro'yxatiga avtomatik yozilmaydi (ataylab — Cash flow «Остаток на счетах» to'g'ri; sotuvni tranzaksiyaga yozish Faza 4 moliya-integratsiyasида).

- 🔜 **Faza 4 (backend/model kerak):** §21 sklad **Перемещения** — per-sklad qoldiq modeli talab qilinadi (hozir qoldiq global); §18 **ilova qayta ochilганда saqlanish** — `shared_preferences`/Firestore serializatsiya kerak. (Xatti-harakатга ta'sir qiluvchi holat — zallar/servis/loyallik/limit/rollar/auth — allaqачон `AppState`да, sessiya davomida saqlanadi.)

**Demo kirish (rollarни sinash uchun):** PIN `0000` — Владелец · `1111` — Управляющий · `2222` — Админ зала · `3333` — Официант · `5555` — Повар · `6666` — Маркетолог.

---

## 1. Qisqacha xulosa (eng muhimi)

Prototip **vizual jihatdan Poster'ga juda o'xshaydi va ishga tushadi** — chiziqli (retail) savdo oqimi (katalog → chek → bo'lib to'lash → kvitansiya → arxiv) haqiqatan ham sifatli qilingan. Ammo **ostida bu yupqa maket**: backend yo'q, ma'lumotlarning katta qismi xotirada va ekrandan chiqilganda yo'qoladi, boshqaruvlarning ko'pi «Saqlash = toast» ko'rinishidagi qobiq.

Ilova hozircha **restoran POS emas, balki oddiy do'kon kassasi**. Restoran-POSni tashkil qiluvchi butun qatlam yo'q:

- 🔴 **Login / Register yo'q** — ilova har safar egasi (Владелец) sifatida to'g'ridan-to'g'ri ochiladi.
- 🔴 **Rollar o'rtasida munosabat / huquqlar matritsasi yo'q** — rollar faqat matn, hech narsani cheklamaydi. Ofitsiant = Egasi bilan bir xil to'liq huquq.
- 🔴 **Zallar va stollar (карта зала) yo'q** — «stol» faqat matn maydoni, hech qachon to'ldirilmaydi. Necha zal, nechta stol, necha kishilik — hech biri yo'q.
- 🔴 **Ofitsiant xizmati oqimi yo'q** — POS rolni umuman bilmaydi.
- 🔴 **Mahsulot rasmlari yo'q** — faqat 16 ta emoji (rasm yuklash kutubxonasi ham yo'q).
- 🔴 **Sotuv sklad qoldig'ini kamaytirmaydi** — retsept→ingredient bog'lanishi ishlamaydi (POSning eng asosiy invarianti).
- 🟠 **Servis foizi (обслуживание), yaxlitlash, mehmonlar soni, xavfsizlik paroli** — sozlamada bor, lekin **o'lik** (hech kim o'qimaydi).

Sizning topgan 6 ta kamchiligingiz **to'liq tasdiqlandi** va ular ro'yxatning faqat bir qismi. Quyida jami **~80 ta** aniqlangan kamchilik muhimlik darajasi va dalil (fayl:qator) bilan keltirilgan.

**Muhimlik yig'indisi:** 🔴 Kritik — 8 · 🟠 Muhim — ~48 · 🟡 Kichik — ~24 (jami ~80)

---

## 2. Ildiz sabab: «backend yo'q» va ikki qatlamli ma'lumot

`app_state.dart:5` da ochiq yozilgan: *«Backend YO'Q — barchasi xotirada»*. Bu prototip uchun ataylab, lekin aynan shu narsa quyidagi kritik kamchiliklarning aksariyati ildizi:

1. **Ikki qatlamli ma'lumot.** Faqat kassa yakunlagan sotuv yozadigan narsalar (`receiptsArchive`, `salesToday`, `topProducts`, `paymentMethods`, hisob balanslari, kassir `revenue`) — **jonli**. Vaqt qatorlari va per-obyekt taqsimot (`byHour`, `byWeekday`, `chartSeries`, `abc`, `client.totalSpent`, P&L, smenalar, oyliklar) — **doim nol yoki hardcode**, chunki kassa ularni hech qachon to'ldirmaydi.
2. **«Saqlash = toast» antipaterni** (kodda 27 ta `showToast`). Loyallik, istisnolar, P&L ulash, kategoriya toggle'lari, ilova o'rnatish, to'lov — hammasi tasdiq toasti ko'rsatadi, lekin `AppState`ga yozmaydi.
3. **Ekran-lokal holat.** Должности, кассы, sessiyalar, tokenlar va deyarli barcha sozlama maydonlari `Navigator.push`da qayta yaratiladigan `State` ichida yashaydi → **navigatsiyadan keyin yo'qoladi**.

> `errlog.txt` (0.6 MB) — bu Android runtime logcat dampи (SurfaceFlinger/display), **build yoki analyze xatosi emas**. Demak ilova kompilyatsiya bo'ladi va qurilmada ishlaydi.

---

## 3. 🔴 KRITIK kamchiliklar (batafsil)

### 3.1 Autentifikatsiya yo'q — login/register umuman qilinmagan
- **Joriy holat:** `main.dart:30` → `home: const RootScaffold()` shartsiz. `currentUser` hardcode egaga o'rnatilgan (`app_state.dart:127`). `screens/` da `login_screen`/`register_screen`/`auth` fayllari **umuman yo'q** (grep bilan tasdiqlandi).
- **Kerak:** Poster admin-paneliga email+parol bilan kirish; POS terminal — kassa login/parol; ro'yxatdan o'tish (trial akkaunt yaratish) varonkasi.
- **Ta'sir:** Ilova har safar to'liq huquqli egasi sifatida ochiladi. Ko'p qurilma / ko'p foydalanuvchi / xavfsizlik tushunchasi yo'q.
- **Muhimlik:** 🔴 Kritik · **Turkum:** Yetishmayotgan funksiya

### 3.2 Kassa PIN'i — himoya emas, chetlab o'tsa bo'ladi
- **Joriy holat:** PIN ekrani faqat **Kassa tab ichida** chiqadi (`kassa_screen.dart:41`). Tab-panel hamma yerda ko'rinadi (`root_scaffold.dart:54`), shuning uchun boshqa tabga bosib (Главная, Меню, Склад, Ещё) **PINsiz butun admin ilovadan** (jumladan Сотрудники, Настройки, Финансы) foydalanish mumkin. PINlar `employees_screen.dart:296` da 👁 bilan ochiq ko'rsatiladi; lockout/hash yo'q.
- **Kerak:** PIN terminalni butunlay bloklashi kerak.
- **Muhimlik:** 🔴 Kritik · **Turkum:** Bug / Xavfsizlik

### 3.3 Rollar va huquqlar matritsasi yo'q (rollar o'rtasida munosabat yo'q)
- **Joriy holat:** `grep hasPermission|canAccess|permission` → **0 natija**. `AppState.roles` (`app_state.dart:49`) — shunchaki `List<String>`, faqat dropdown to'ldiradi. Должность muharriridagi huquq-galochkalari (`employees_screen.dart:486`) ekran-lokal `_Position.rights`ga yoziladi va **hech qayerda tekshirilmaydi**. `more_screen.dart:31` dagi har bir plitka roldan qat'i nazar ochiladi.
- **Natija:** «Официант» yoki «Повар» roli Egasi bilan **bir xil** to'liq huquq oladi. Egаsi > Menejer > Administrator > Ofitsiant ierarxiyasi yo'q (faqat bitta hardcode «Владелец» qulfi).
- **Muhimlik:** 🔴 Kritik · **Turkum:** Yetishmayotgan funksiya

### 3.4 Ofitsiant xizmati oqimi yo'q — POS rolni bilmaydi
- **Joriy holat:** «Официант» roli `app_state.dart:49` da **mavjud**, lekin `tryLogin` (`kassa_controller.dart:58`) faqat `user`ni o'rnatadi; **hech bir joyda `user.role` bo'yicha shoxlanish yo'q**. Ofitsiant uchun stol tanlash, «mening buyurtmalarim», voidlar/skidkalarni cheklash — hech biri yo'q. Kvitansiyadagi `waiter` maydoni doim **kassir** ismi bilan to'ldiriladi (`kassa_controller.dart:166`).
- **Kerak:** Har xodim o'z PINi bilan kiradi, rol asosidagi huquqlar (audit `09-pos-terminal.md §0`).
- **Muhimlik:** 🔴 Kritik · **Turkum:** Yetishmayotgan funksiya

### 3.5 Zallar / stollar / karta зала yo'q
- **Joriy holat:** `models.dart` da `Hall`/`Table`/`Zone`/`Floor` klassi **yo'q** (grep bilan tasdiqlandi). `OpenOrder.table` — `String?` (faqat matn yorlig'i, `models.dart:182`) va **faqat ko'rsatish uchun o'qiladi**; hech bir ekranda `OpenOrder(...)` yaratilmaydi → «Заказы» tab amalda **doim bo'sh**. Faol chekda (`CheckDoc`) stol maydoni umuman yo'q. Necha kishilik o'rin (sig'im/seats) tushunchasi yo'q.
- **Kerak:** POS ochilganda **zal xaritasi** — zal tanlash, stollarni fazoviy joylashuvda ko'rish, stolga bosib buyurtma ochish/davom ettirish. Zalda nechta stol, har stol necha kishilik, band/bo'sh holati.
- **Muhimlik:** 🔴 Kritik · **Turkum:** Yetishmayotgan funksiya

### 3.6 «Карта зала на кассе» va «мехмонлар сони» — o'lik toggle'lar
- **Joriy holat:** `_hallMap`/`_guestsQ` (`settings_screen.dart:26-27,504-505`) — lokal bool, **hech kim o'qimaydi**. Toggle ostida zal xaritasi ham, mehmon so'rovi ham mavjud emas.
- **Muhimlik:** 🟠 Muhim · **Turkum:** Yarim ishlangan (o'lik toggle)

### 3.7 Mahsulot rasmlari yo'q — faqat emoji
- **Joriy holat:** `Product.photo` — `String photo; // emoji` (`models.dart:22`). Forma faqat **16 ta qattiq emoji** tavsiya etadi (`product_form.dart:27` `_kEmojis`); yorliq: «Эмодзи-обложка · 🍽». `pubspec.yaml` da `image_picker`/`file_picker` **yo'q**; `lib/` da `ImagePicker/Image.file/XFile` — **0 ta** (grep bilan tasdiqlandi). Sklad/tех.карта yangi tovarga `📦`/`🍽` hardcode.
- **Kerak:** Haqiqiy rasm yuklash (galereya/kamera), rasm bo'lmasa nomdan harfli placeholder («КОЛ»).
- **Muhimlik:** 🔴 Kritik · **Turkum:** Yetishmayotgan funksiya

### 3.8 Sotuv sklad qoldig'ini kamaytirmaydi (retsept→ombor bog'i uzuq)
- **Joriy holat:** To'lovda (`kassa_controller.dart:172-208`) revenue/profit/checks/paymentMethods/topProducts yangilanadi, lekin **`ingredient.stock`ga umuman tegilmaydi**. Retseptlar hardcode `_kRecipes` map'ida id bo'yicha (`menu_screen.dart:689`), forma esa retseptni **saqlamaydi** (`product_form.dart:269` faqat name/cat/price/cost). `AppState.completeSale` (`app_state.dart:201`) — **o'lik kod** (chaqirilmaydi).
- **Kerak:** Kapuchino sotilsa — stakan 100→99, suv 10→9.960 л (audit `04-ombor.md 4.1`, Poster'ning bosh xususiyati).
- **Muhimlik:** 🔴 Kritik · **Turkum:** Yetishmayotgan funksiya / Yarim ishlangan

### 3.9 Servis foizi (обслуживание) hech qachon qo'llanmaydi
- **Joriy holat:** `_service` (`settings_screen.dart:30`) — qattiq chiplar (Не использовать / 5% / 10%), ixtiyoriy % kiritib bo'lmaydi va **chek hisobiga hech qachon qo'shilmaydi** (`kassa_controller.dart` dagi `dueFor` da servis a'zosi yo'q). Kvitansiyada servis qatori yo'q.
- **Kerak:** Zal buyurtmasiga servis foizi qo'shilishi; zallar/stollar va servis foizini **alohida** tahrirlash imkoni.
- **Muhimlik:** 🟠 Muhim · **Turkum:** Yarim ishlangan (dekorativ boshqaruv)

---

## 4. Modul-modul kamchiliklar jadvallari

Turkum belgilari: **YF**=Yetishmayotgan funksiya · **YI**=Yarim ishlangan · **B**=Bug · **UX**=UX/dizayn.

### 4.1 Kassa / POS terminal

| # | Kamchilik | Dalil (fayl:qator) | Muhim | Turkum |
|---|---|---|---|---|
| K-1 | Zal/stol modeli yo'q, «stol» — matn (§3.5) | models.dart:182 | 🔴 | YF |
| K-2 | POS rolni bilmaydi, ofitsiant oqimi yo'q (§3.4) | kassa_controller.dart:58 | 🔴 | YF |
| K-3 | Yangi buyurtmani tur/stolga bog'lab bo'lmaydi; «Заказы» amalda bo'sh | orders_screen.dart:46, kassa_controller.dart:123 | 🟠 | YI |
| K-4 | Mehmonlar soni so'ralmaydi | settings_screen.dart:27 | 🟠 | YF |
| K-5 | Online/offline indikator hardcode yashil; **oflayn rejim yo'q** | kassa_screen.dart:123 | 🟠 | YF |
| K-6 | Kassa smenasini ochish/yopish yo'q (X-otchyot «Смена не закрывается» deydi) | functions_sheet.dart:90 | 🟠 | YF |
| K-7 | Vozvrat to'lov-usuli/kassa yashigi/kassir statistikasini qaytarmaydi (faqat `salesToday`) → X-otchyot va arxiv ziddiyati | orders_screen.dart:369 | 🟠 | B |
| K-8 | X-otchyotda sana/kassir/«по товарам» — soxta (tahrirlanmaydi, param ishlatilmaydi) | functions_sheet.dart:92,134 | 🟠 | B/YI |
| K-9 | Void/o'chirish/«без оплаты» — parol so'ramaydi (xavfsizlik sozlamasi ta'sir qilmaydi) | kassa_screen.dart:725 | 🟠 | YF |
| K-10 | Oshxona «бегунок»i yo'q — `Product.workshop` POSda ishlatilmaydi | models.dart:19 | 🟠 | YF |
| K-11 | Shtrix-kod skaneri — toast zaglushka | kassa_screen.dart:277 | 🟡 | YI |
| K-12 | «Акции» tugmasi hech qachon aksiya qo'llamaydi | kassa_screen.dart:281 | 🟡 | YI |
| K-13 | Modifikator narx qo'shmaydi (`Modification` = faqat nom); qator-skidka yo'q | models.dart:9 | 🟡 | YF |
| K-14 | «Режим сортировки» — atayin no-op; «денежный ящик» drawerni ochmaydi | functions_sheet.dart:59,64 | 🟡 | YI |
| K-15 | Yaxlitlash / «продажа части порции» sozlamalari qo'llanmaydi | settings_screen.dart:28-29 | 🟡 | YI |
| K-16 | Arxiv qidiruvi faqat chek id bo'yicha; «Сегодня ▾» davri soxta; arxiv chop etish — demo toast | orders_screen.dart:189,201,329 | 🟡 | YI |

**Yaxshi ishlaydi:** bo'lib to'lash (split), parallel cheklar dropdown, arxiv+filtrlar+vozvrat, pozitsiya detali (miqdor ±, izoh), mijozni biriktirish + bonus/skidka — barchasi spetsifikatsiyaga mos va sifatli.

### 4.2 Menyu va mahsulotlar

| # | Kamchilik | Dalil | Muhim | Turkum |
|---|---|---|---|---|
| M-1 | Haqiqiy rasm yuklash yo'q — emoji (§3.7) | models.dart:22, product_form.dart:27 | 🔴 | YF |
| M-2 | Retsept saqlanmaydi + id bo'yicha hardcode `_kRecipes` collision → noto'g'ri состав; tех.картani tahrirlashda retsept qayta yuklanmaydi | product_form.dart:161,269; menu_screen.dart:689 | 🔴 | B/YI |
| M-3 | Полуфабрикаты (yarim tayyor) umuman yo'q | models.dart:17 | 🟠 | YF |
| M-4 | Tех.карта formasi: shtrix-kod, tayyorlash jarayoni/vaqti, obложка, весовая, per-qator usul — yo'q; modifikatorlar «Business/Pro» disabled badge | product_form.dart:169-284 | 🟠 | YF/YI |
| M-5 | Kategoriya rangi tanlanmaydi/ko'rsatilmaydi (hardcode `0xFFD97757`); emoji nom→emoji hardcode map | menu_screen.dart:580,766 | 🟠 | YI |
| M-6 | Kategoriya: ota/sub-kategoriya (daraxt), foto, reorder yo'q; formada inline «yangi kategoriya» yo'q | app_state.dart:24; product_form.dart:12 | 🟠 | YF |
| M-7 | Mahsulot formasida shtrix-kod, НДС yo'q; modifikatsiya faqat nom (per-mod narx/kod yo'q) | product_form.dart:94; models.dart:9 | 🟠 | YF/YI |
| M-8 | Цехи ekran-lokal (`_shops`), `AppState`da emas; tovar formasidagi ro'yxat alohida hardcode; toggle saqlanmaydi; печать routing yo'q | menu_screen.dart:23; product_form.dart:28 | 🟠 | YI |
| M-9 | Ingredient «% потерь» (очистка/варка/жарка) maydoni yo'q, forма ham | models.dart:44; menu_screen.dart:510 | 🟠 | YF |
| M-10 | Mahsulotlar ro'yxatida ustunlar/eksport/pechat/bulk-delete/цех filtri yo'q | menu_screen.dart:106 | 🟡 | UX |
| M-11 | «Дублировать» modifikatsiyalarni yo'qotadi | menu_screen.dart:474 | 🟡 | B |
| M-12 | Nomdan harfli placeholder yo'q; весовой uchun birlik/qadam yo'q | product_form.dart:74 | 🟡 | YI |

### 4.3 Sklad (ombor)

Spetsifikatsiyada 10 submodul; holati:

| Submodul | Holat | Izoh (dalil) |
|---|---|---|
| Остатки | Qisman | Лимит **hardcode `1`**, tahrirlab bo'lmaydi (sklad_screen.dart:163); tovar qoldig'i **ekran-lokal** `_prodStock` (sklad_screen.dart:43), navigatsiyada yo'qoladi |
| Поставки | ✅ Yaxshi | Счет ustuni, CSV import, Фасовки yo'q; postavshchik statistikasi yangilanmaydi |
| Списания | Qisman | «Причины» справочник yo'q (hardcode chiplar); faqat ingredient |
| **Перемещения** | ❌ Yo'q | Tab, forma, model yo'q |
| **Переработки** | ❌ Yo'q | Umuman yo'q |
| **Отчёт по движению** | ❌ Yo'q | Umuman yo'q |
| Инвентаризации | ✅ Yaxshi | Faqat «Полная» (Частичная yo'q); faqat ingredient |
| Поставщики | ✅ | Tahrirda faqat nom+telefon saqlanadi; count/sum yangilanmaydi (sklad_screen.dart:669) |
| Склады | Qisman | Alohida ro'yxat/tab yo'q; adres/summa/edit/delete yo'q |
| **Фасовки** | ❌ Yo'q | Yo'q |

- **S-arx:** Ko'p-sklad **fiksiya** — bitta global `ingredient.stock`, per-sklad miqdor yo'q; barcha ko'chirish/inventar bir sonni o'zgartiradi (`models.dart:47`). 🟠

### 4.4 Xodimlar va Dostup

| # | Kamchilik | Dalil | Muhim | Turkum |
|---|---|---|---|---|
| X-1 | Huquqlar matritsasi yo'q (§3.3) | employees_screen.dart:486 | 🔴 | YF |
| X-2 | Должности saqlanmaydi + `AppState.roles` bilan sinxron emas | employees_screen.dart:69 | 🟠 | YI/B |
| X-3 | Rolni o'chirish yo'q; ierarxiya yo'q; «Полный доступ» yaratса bo'ladi | employees_screen.dart:475,571 | 🟠 | YF |
| X-4 | Oylik stavkasi kiritiladi, lekin **tashlab yuboriladi** (faqat name+rights saqlanadi) | employees_screen.dart:574 | 🟠 | YI |
| X-5 | Xodim **paroli** va «qaysi заведение» saqlanmaydi | employees_screen.dart:363,376 | 🟠 | YI |
| X-6 | Сессии (user_sessions) — soxta statik ma'lumot; «Завершить все» real emas | employees_screen.dart:82,749 | 🟠 | YF |
| X-7 | «Выйти» aslida chiqmaydi — faqat Kassa tabga o'tadi | more_screen.dart:164 | 🟠 | B |
| X-8 | Per-xodim revenue faqat PIN qilgan kassir uchun ishlaydi | kassa_controller.dart:201 | 🟡 | YI |
| X-9 | Токенлар (интеграции) — soxta lokal LCG token, API yo'q | employees_screen.dart:86,904 | 🟡 | YI |

### 4.5 Sozlamalar

| # | Kamchilik | Dalil | Muhim | Turkum |
|---|---|---|---|---|
| SZ-1 | Zallar/stollar boshqaruvi umuman yo'q (§3.5) | — | 🔴 | YF |
| SZ-2 | «Карта зала»/«гости» toggle o'lik (§3.6) | settings_screen.dart:26 | 🟠 | YI |
| SZ-3 | Servis foizi qo'llanmaydi (§3.9) | settings_screen.dart:30 | 🟠 | YI |
| SZ-4 | Заведения — 1 ta hardcode; «Добавить» = Business upsell; login ustuni yo'q | employees_screen.dart:651,697 | 🟠 | YF |
| SZ-5 | Кассы — lokal; parol hardcode `kassa•2026`; «Выход» real emas | employees_screen.dart:78,626 | 🟠 | YI |
| SZ-6 | Источники/методы оплаты — lokal, kassa/to'lov ekrani o'qimaydi (Click/Payme chiqmaydi) | settings_screen.dart:41; payment_screen.dart | 🟠 | YI |
| SZ-7 | Доставка — toggle lokal, dostavka oqimi yo'q | settings_screen.dart:50 | 🟠 | YI |
| SZ-8 | Безопасность — admin parol gating umuman ishlamaydi (hech qaysi amal parol so'ramaydi) | settings_screen.dart:54 | 🟠 | YF |
| SZ-9 | Chek sozlamalari — jonli preview bor, lekin saqlanmaydi; «Сохранить» faqat toast | settings_screen.dart:689 | 🟡 | YI |
| SZ-10 | Umumiy sozlamalar bloki asosan inert; faqat «Кассовые смены» va kompaniya nomi haqiqatan ulanган | settings_screen.dart:23,517 | 🟠 | YI |

### 4.6 Statistika

Spetsifikatsiyada **11 sahifa**, kodda **8 tab**.

| # | Kamchilik | Dalil | Muhim | Turkum |
|---|---|---|---|---|
| ST-1 | **Клиенты** hisobot sahifasi yo'q | stats_screen.dart:28 | 🟠 | YF |
| ST-2 | **Цехи** hisobot sahifasi yo'q | — | 🟠 | YF |
| ST-3 | **Налоги** sahifasi yo'q + `Product`da soliq maydoni yo'q | models.dart:14 | 🟠 | YF |
| ST-4 | Sana-oralig'i tanlagich yo'q; «Неделя»/«Месяц» → hammasi **0** (hardcode nol) | stats_screen.dart:40,221 | 🟠 | B/YF |
| ST-5 | «По времени»/«По дням» grafiklari doim nol (byHour/byWeekday to'lmaydi) | stats_screen.dart:40; app_state.dart:77 | 🟠 | YI |
| ST-6 | Продажи: to'lov-usuli bloki, KPI-tab grafik almashtirgich, chiziqli grafik yo'q | stats_screen.dart:228 | 🟠 | YF |
| ST-7 | ABC-анализ hech qachon hisoblanmaydi (`abc=[]`) | app_state.dart:98 | 🟠 | YI |
| ST-8 | Оплаты — soxta tarix (÷65263, 60/40 split) | stats_screen.dart:903 | 🟡 | B/YI |
| ST-9 | Отзывы — faqat bo'sh holat (dizayn bo'yicha OK) | stats_screen.dart:976 | 🟡 | YI |
| ST-10 | Har sahifada Столбцы/Экспорт/Печать yo'q | stats_screen.dart:69 | 🟡 | UX |

**Yaxshi:** Чеки, Товары, Категории, Сотрудники tablari — jonli va to'g'ri hisoblaydi.

### 4.7 Moliya

Spetsifikatsiyada 7 bo'lim, kodda **5 chip**.

| # | Kamchilik | Dalil | Muhim | Turkum |
|---|---|---|---|---|
| F-1 | **Cash flow** hisoboti yo'q | finance_screen.dart:19 | 🟠 | YF |
| F-2 | **Зарплата** hisoboti yo'q (+stavka/smena modeli yo'q) | models.dart:80 | 🟠 | YF |
| F-3 | P&L — 100% hardcode demo, real `transactions`ga ulanmaydi | finance_screen.dart:568 | 🟠 | YI |
| F-4 | Кассовые смены — 2 ta soxta hardcode smena | finance_screen.dart:436 | 🟠 | YI |
| F-5 | Kategoriya toggle'lari (На кассе/В P&L) saqlanmaydi, inert | finance_screen.dart:28 | 🟡 | YI |
| F-6 | «Импорт с AI» — 2 ta hardcode tranzaksiya | finance_screen.dart:969 | 🟡 | YI |
| F-7 | Транзакции: davr/eksport/pechat yo'q | finance_screen.dart:200 | 🟡 | YF |
| F-8 | Yangi kategoriya `AppState`ga saqlanmaydi → Add-Transaction dropdownда chiqmaydi | finance_screen.dart:1035 | 🟡 | B |

**Yaxshi:** Транзакции qo'shish/filtr + balans, Перевод (double-entry), Счета — jonli.

### 4.8 Marketing (eng yaxshi qoplangan modul)

| # | Kamchilik | Dalil | Muhim | Turkum |
|---|---|---|---|---|
| MK-1 | Mijoz «Сумма покупок»/tarix hech qachon to'lmaydi (sotuv `totalSpent`ga yozmaydi) | kassa_controller.dart:207; marketing_screen.dart:321 | 🟠 | B/YI |
| MK-2 | Loyallik sozlamalari hech qayerga saqlanmaydi (toast) va kassaga ta'sir qilmaydi | marketing_screen.dart:509 | 🟠 | YI |
| MK-3 | Исключения lokal, kassadagi skidka mantig'i o'qimaydi | marketing_screen.dart:47,921 | 🟠 | YI |
| MK-4 | Акции: muharrir saqlaydi, lekin kassada **qo'llanmaydi**; boy maydonlar reopen'da yo'qoladi | marketing_screen.dart:878 | 🟠 | YI |
| MK-5 | Mijoz import/eksport/pechat/korzina — toast zaglushka | marketing_screen.dart:227 | 🟡 | YF |
| MK-6 | Mijoz formasi: email/izoh/jins/adres kiritiladi, lekin **saqlanmaydi** | client_form.dart:88; models.dart:116 | 🟡 | YI |

**Yaxshi:** Клиенты CRUD, Группы CRUD va guruh skidkasi kassada qo'llanadi — bu ishlaydigan yagona loyallik qismi.

### 4.9 Ilovalar / Obuna / Bosh sahifa

| # | Kamchilik | Dalil | Muhim | Turkum |
|---|---|---|---|---|
| A-1 | Marketplace faqat install-toggle; «Узнать больше»/konfig yo'q; Postie AI ekrani yo'q | apps_screen.dart:24 | 🟡 | YI |
| A-2 | Obuna/tarif to'lovi kosmetik lokal holat | subscription_screen.dart:22 | 🟡 | YI |
| A-3 | Bosh sahifa grafigi (`chartSeries`) doim nol → tekis chiziq; «+X%» o'sish doim +0% | home_screen.dart:363; app_state.dart:74 | 🟠 | YI/B |
| A-4 | «Взгляните на отчёты» onboarding qadami hardcode `done:false` | home_screen.dart:215 | 🟡 | B |

**Yaxshi:** Bosh sahifa KPI, to'lov-usullari, ommabop tovarlar, ochiq buyurtmalar, kam qoldiq ogohlantirishi, «Ещё» hub sanoqlari — jonli.

---

## 5. Kod sifati va tizimli buglar

1. **O'lik kod:** `AppState.completeSale` (`app_state.dart:201`) hech qachon chaqirilmaydi va hatto naqd qo'shishni boshqacha (noto'g'ri) hisoblaydi — kelajakda ulansa latent bug.
2. **Vozvrat ma'lumot yaxlitligini buzadi** (K-7): `paymentMethods`, kassa yashigi balansi, kassir `revenue/checks` vozvratdan keyin oshib qoladi → X-otchyot va arxiv bir-biriga zid.
3. **Ekran-lokal holat yo'qolishi** — tizimli: должности, кассы, sessiyalar, tokenlar, deyarli barcha sozlamalar navigatsiyada yo'qoladi (`AppState` ularni saqlamaydi).
4. **«Saqlash = toast»** — 27 ta `showToast`; ko'pi hech narsa saqlamaydi (loyallik, istisnolar, P&L, kategoriya toggle, ilova o'rnatish, billing).
5. **Hardcode «minalar»:** `_shops`, `_prodStock`, `_kRecipes`, `_kCatEmoji`, `_kIngEmoji`, `_kShops`, `limit:1`, kategoriya rangi `0xFFD97757`, P&L raqamlari, smenalar, оплаты ÷65263.
6. **Ma'lumot modeli o'ta soddalashtirilgan:** bitta `Product` klassi tovar+тех.карта rolini bajaradi; retsept/полуфабрикат/shtrix-kod/НДС/rang/rasm-fayl maydonlari yo'q — bu §3.7/§3.8 va M-2/M-3/M-5/M-7 ildizi.
7. **Kategoriya-emoji va ingredient-emoji nom bo'yicha** hardcode map — ma'lumotga asoslanmagan, ro'yxatdan tashqari nom uchun umumiy emoji.

> **Buglar toʻliq roʻyxati:** M-2, M-11, K-7, K-8, X-2, X-7, F-8, MK-1, A-3, A-4 + tizimli 1–3.

---

## 6. UX / dizayn nomuvofiqliklari

- **Bosh sahifa/statistika grafiklari** professional chizilgan, lekin ma'lumot nol → **doim tekis/bo'sh** ko'rinadi (yomon taassurot).
- **Chop etish yo'llari ikki xil:** precheck/to'lov real ESC/POS, arxiv esa «демо» toast — nomuvofiq.
- **Global toolbar yo'q** (Столбцы/Экспорт/Печать/Импорт + kalendar sana-oралиq) — spetsifikatsiya buni universal admin naqsh deb belgilaydi; Statistika/Moliyada yo'q.
- **Sana filtri hech qayerda yo'q** — har «davr» boshqaruvi yo buzilgan 3-tugma yoki umuman yo'q.
- **Empty-state matni** ba'zan spetsifikatsiyadan farq qiladi (mijoz tabida onboarding o'rniga «Клиент не найден»).
- **Modifikator variantlari** bazaviy narxni ko'rsatadi (narx farqi yo'q) — foydalanuvchini chalg'itadi.
- **Tab ikonkalari emoji** (🏠🛒📋📦⋯) — vektor ikonка emas; brendlash/aniqlik cheklangan.
- **«Выйти»/«Выход»/«Завершить сессии»** yo'lakay matnlari real bajarmaydigan va'da beradi (chalg'ituvchi).

---

## 7. Nima YAXSHI ishlaydi (balans uchun)

Bu — real, ishlaydigan prototip; quyidagilar sifatli:

- Chiziqli savdo: katalog → chek → **bo'lib to'lash (split)** → kvitansiya → **arxiv + vozvrat**.
- **Parallel ochiq cheklar** (dropdown), pozitsiya detali (miqdor ±, izoh), tez-summa tugmalari, bo'sh to'lovda qizil «shake» validatsiya.
- Mijozни biriktirish + **guruh skidkasi + bonus** kassada haqiqatan qo'llanadi.
- Транзакции + **Перевод (double-entry)** + Счета balansi; Инвентаризация; Поставка (qoldiqni oshiradi, qarz/postavshchik).
- Статистика Чеки/Товары/Категории/Сотрудники — jonli hisob.
- Real **WiFi ESC/POS printer** integratsiyasi (discovery, CP866) — precheck/to'lovda ishlaydi.
- Trial kunlari `trialEndsAt`dan dinamik; «Ещё» hub sanoqlari jonli.

---

## 8. Yo'l xaritasi (bosqichma-bosqich tuzatish rejasi)

Tavsiya: avval **poydevor** (backend + auth + ma'lumot qatlami), keyin restoran-POS qatlami, so'ng hisobotlar.

### Bosqich 0 — Poydevor (eng avval, hammasi shunga bog'liq)
1. **Backend (Firebase: Auth, Firestore, Storage, FCM)** — README'dagi 2-bosqichni boshlash.
2. **Login/Register ekranlar** (§3.1) + kompaniya yaratish/trial.
3. **Persistent store** — barcha ekran-lokal holatni (должности, кассы, sozlamalar, sessiyalar) `AppState`/Firestore'ga ko'chirish (tizimli bug #3ni yopadi).

### Bosqich 1 — Restoran-POS yadrosi (sizning asosiy talablaringiz)
4. **Rollar + huquqlar matritsasi** (§3.3) — RBAC, ekranlarni/amallarni rol bo'yicha cheklash; Egаsi>Menejer>Admin>Ofitsiant ierarxiyasi.
5. **Ofitsiant PIN oqimi** (§3.2, §3.4) — PIN butun terminalni bloklaydi; ofitsiant = faqat o'z stollari/kassa.
6. **Zallar va stollar** (§3.5): `Hall`/`Table` modellari (zal, stol №, **necha kishilik**, holat), **zal xaritasi** ekrani, stolni chekka bog'lash, mehmonlar soni.
7. **Zal/stol tahriri + servis foizini alohida** (§3.6, §3.9) — sozlamalarda haqiqiy CRUD; servisni chek hisobiga qo'shish.

### Bosqich 2 — Menyu va sklad haqiqiyligi
8. **Mahsulot rasm yuklash** (§3.7) — `image_picker`/Firebase Storage; placeholder.
9. **Retsept→sklad** (§3.8) — retseptni saqlash, sotuvda ingredient hisobdan chiqarish; полуфабрикаты.
10. Цехи global + «бегунок» oshxonaga; ingredient «% потерь»; ko'p-sklad real miqdorlar.

### Bosqich 3 — Hisobotlar va moliya
11. Vaqt qatorlarini sotuvdan to'ldirish (`byHour`, `byWeekday`, `chartSeries`, `abc`, `client.totalSpent`).
12. Yetishmayotgan sahifalar: Статистика (Клиенты, Цехи, Налоги), Moliya (Cash flow, Зарплата), real P&L va smenalar.
13. Sana-oралиq tanlagich + Столбцы/Экспорт/Печать toolbar.

### Bosqich 4 — To'ldirish
14. Marketing: loyallik/aksiya/istisnolarni kassaga real ulash; mijoz formasi maydonlarini saqlash.
15. Xavfsizlik paroli gating; oflayn rejim; kassa smenasi lifecycle; vozvrat yaxlitligi (K-7).
16. Shtrix-kod skaneri, НДС, modifikator narxlari, import/eksport.

---

## 9. Ilova: tekshirish metodikasi

- 4 ta parallel agent har modulni `audit/*.md` bilan qator-qator solishtirdi.
- Asosiy da'volar mustaqil `grep` bilan tasdiqlandi: login/register fayllari **yo'q**; `image_picker`/`file_picker` **yo'q**, `ImagePicker/XFile` **0 ta**; `Hall/Table/Zone` klassi **yo'q**, `OpenOrder(...)` hech qachon yaratilmaydi; `permission` **0 ta**; servis faqat `settings_screen.dart` da.
- `errlog.txt` runtime logcat ekani tekshirildi (build xatosi emas) → ilova ishlaydi.
- Sandboxда `flutter`/`dart` yo'qligi sababli `flutter analyze` ishga tushirilmadi; kod sifati statik o'qish va grep bilan baholandi.
