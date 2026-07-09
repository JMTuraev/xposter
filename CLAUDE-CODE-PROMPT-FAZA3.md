# Claude Code uchun prompt — Buxoro POS · FAZA 3 tekshiruvi

> Quyidagi matnни to'liq Claude Code'ga (terminalда `D:\poster`) yuboring.

---

Sen `D:\poster\buxoro_pos` (Flutter, Poster POS analogi, ruscha, Android) ilовасини build qilib, ulanган telefonда ишга tushириб, **FAZA 3** o'zгаришларини tekshириб berишинг kerak. Kod kompилятsiясiz yozилган — avval `flutter analyze` error'larini topib tuzat, keyin qurilмада sинаб ko'r va hisobot ber.

To'liq o'zгаришлар: **`D:\poster\AUDIT-KAMCHILIKLAR.md`** («0. TUZATISH JURNALI» → «Faza 3» bo'limи).

⚠️ **Feature kodini O'CHIRMA/QAYTARMA** — faqat kompиляция xatоларини tuzat.

## Qadamlar
1. `cd D:\poster\buxoro_pos`
2. `flutter pub get`
3. `flutter analyze` — **`error`larni tuzat.** (Kutилаётган `warning`/`info` — muhим EMAS: `no_leading_underscores_for_local_identifiers` (stats histogram ичидаги `final _hourVals`/`_dayVals`), va `unused_*` (`_kRecipes`, `_hourVals`, `_dayVals`, `app_stateMonth` endi ишлатилмайди). Bular build'ни buzмайди.)
4. `flutter devices` → `flutter run -d <device_id>` yoki `rebuild_and_install.bat`.
5. Pastдаги ro'yxат bo'yicha sинаб ko'r.
6. Hisobот ber.

## FAZA 3 — tekshирув ro'yxати
Kirish: PIN **0000** (Владелец — hammага ruxsат). Avval Kassaда 1-2 sotuv qil (grafик/statистика to'lиши учун).

**§20 Статистика** (Ещё → Статистика):
1. [ ] Sotuvdан keyin **«По времени»** (soatlik) va **«По дням недели»** grafiklaridа ustunlar paydо bo'lди (ilgari tekis nol edi).
2. [ ] «Неделя» va «Месяц» tanlaganда **crash bo'lмайди** va raqamlar ko'ринади (ilgari 0 va yiqилиш xavfи bor edi).
3. [ ] Yangi tab'lar ochилади va to'ldiрилади: **Клиенты** (xarид summаsи+bonus), **Цехи** (цех bo'yicha vyручка/pribil), **Налоги** (halol «не настроены» holati).

**§21 Финансы** (Ещё → Финансы):
4. [ ] **Cash flow** tab — kategoriya bo'yicha Поступления/Выбытия, «Чистый поток», «Остаток на счетах».
5. [ ] **Зарплата** tab — должность bo'yicha штат ro'yxати + izoh.

**§21 Склад** (Склад → Переработки):
6. [ ] Kamида 2 ingredient bo'lса — **«Переработки»** tab + `＋` → «Из чего»/«Во что» + miqdorlар → «Переработать». Natижада **Остатки**да manbа kamаяди, natижа oshади; Переработки ro'yхатida yozuv chiqади.

**Маркетинг loyallik** (Ещё → Маркетинг → Лояльность):
7. [ ] «💎 Бонусная система»да **«Бонус за покупку, %»** maydoni bor; qiymат kirит (masalan 5) → «Сохранить».
8. [ ] Kassaда mijоzни biriktir → sotuv → **mijoz bonusi oshди** (xariднинг 5%i). Маркетинг → Клиенты kartaсida yoki Статистика → Клиентда ko'rин.
9. [ ] «Приветственный бонус»ни > 0 qil, saqlа → **yangi mijoz** yaratганда o'sha bonus bilan ochилади.

**§21 Ombor limiti** (Меню → Ингредиенты → ＋, yoki Склад → ＋ → Ингредиент):
10. [ ] Formadа **«Лимит»** maydoni bor; masalan qoldiq 1, limit 2 kirит → Остаткида ⚠️ «ниже лимита» chiqади (ilgari limit doim 1 edi).

## Qisqа regressiya (asосий oqim buzилмаганини tekshir)
- [ ] Login → PIN 3333 (Официант) faqat Kassa/Zal ko'ради; 0000 hammаsи.
- [ ] Kassa → zal xaritаси → stol → mehmon soni → chek; «Обсл.» servis foizи chekда.
- [ ] Тех.карта rasm + retsept saqlanади; sotувда ingredient kamаяди.

## E'tibor beriladigan joylar (xato chiqsa)
- `stats_screen.dart`: `_hourHistogram(List<int> source)` / `_dayHistogram(List<int> source)` — ichида `final _hourVals = source;` (shadow). Agar analyzer буни error qilса (odatда faqat lint) — o'zгарувчини `hv`/`dv` deb qайта nomlа va ичкi reflarни moslа.
- `finance_screen.dart`: `_cashflow` ичида lokal `group(...)` funksiyasi (collection `if/for`). 
- `marketing_screen.dart`: `didChangeDependencies` + `context.read<AppState>()` (loyallik init).
- Type: yangi kodда list-index учун `.clamp(...).toInt()` ишлатилган.
- O'zгарган fayllar: `stats_screen.dart`, `finance_screen.dart`, `sklad_screen.dart`, `menu_screen.dart`, `marketing_screen.dart`, `kassa_controller.dart`, `state/app_state.dart`.

## Hisobот
1. **`flutter analyze`:** necha `error` (bo'lса — fayl:qатор + tuzатиш); warning sonи.
2. **Build/Run:** o'rnатилдими, ишга tushдими (qurilма).
3. **Funksiyalар:** yuqоридаги 10 band + regressiya — har birини ✅/⚠️/❌ + izoh.
4. **Qolган muammоlar** (bo'lса).
5. Iloji bo'lса — Статистика (grafик/Клиенты), Финансы (Cash flow), Склад (Переработки), Маркетинг (Лояльность) ekranларidан screenshot.

Boshlа: `flutter pub get` → `flutter analyze`.
