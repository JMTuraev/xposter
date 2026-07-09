# Claude Code uchun prompt — Buxoro POS build, qurilmага run va tekshiruv

> Quyidagi matnни to'liqligicha Claude Code'ga (terminalда `D:\poster` ochib) yuboring.

---

Sen `D:\poster\buxoro_pos` папкасидаги Flutter ilovасини (Poster POS analogi — «Buxoro POS», ruscha interfeys, Android qurilmага) build qilib, ulangan telefonда ishga tushириб, tekshириб berишинг kerak.

## Muhim kontekst
Ilовага hozиргина KATTA o'zgаришлар киритилди (login/register, rollar-huquqlar, zallar/stollar, servis foizi, mahsulot rasmi, retsept→sklad). Kod **kompилятsiясиз** (flutter'siz muhитда) yozилган, shuning uchun kichик type/syntax xatolари bo'lиши MUMKIN. Sening asосий вазифанг — shu xatolарни topib tuzатиб, ilовани ишлатиб berишинг.

To'liq o'zгаришлар ro'yxати bu fayldа: **`D:\poster\AUDIT-KAMCHILIKLAR.md`** (eng ustидаги «0. TUZATISH JURNALI» bo'limи). Feature ишларишини shu bo'yicha solиштир.

⚠️ **Feature kodини O'CHIRMA/ORTGA QAYTARMA.** Faqat kompиляция xatоларини tuzat va ишлаши учун kerak bo'lган minimal to'g'риlашларни kirit.

## Bajарилиши kerak bo'lган qadamlar (tartib bilan)

1. `cd D:\poster\buxoro_pos`
2. `flutter pub get` — yangi paket qo'шилган: `image_picker: ^1.1.2` (yuklаб olиниши shart).
3. `flutter analyze` — **barcha `error` darajasидагиларни tuzat.** (`warning`/`info` — masalan `unused_element`, ishlатилмаган `_kRecipes` — muhим emas, e'tиborsиз qoldirсанг bo'lади.) Har bir xatони fayl:qatор bilan ko'r, sабабини tushuниб to'g'риla.
4. `flutter devices` — qurilма ulангanини tekshir. Ulанган bo'lса:
   - `flutter run -d <device_id>`  **yoki**  tayyor skript: `D:\poster\buxoro_pos\rebuild_and_install.bat` (flutter build apk + adb install).
   - Agar build APK kerak bo'lса: `flutter build apk --debug` va `install_apk.bat`.
5. Ilова ишга tushгач — pastдаги tekshирув ro'yxати bo'yicha sинаб ko'r (kerак bo'lса `hot reload`).
6. Oxирida to'liq **hisobot** ber (format pastда).

## Tekshирув ro'yxати (yangi funksiyalар)

Demo kirиш PIN'lари: **0000**=Владелец, **1111**=Управляющий, **2222**=Админ зала, **3333**=Официант, **5555**=Повар, **6666**=Маркетолог. Логин/парол: `tnapster@mail.ru` / `123456`.

1. **Login/Register:** ilова to'g'ридан-to'g'ri ичга кирмайди — avval **Login ekрани** chiqади. Логин/парол yoki «Войти по PIN» ишлайди; «Регистрация» yangi akkаunt yaraтади.
2. **Rollar (RBAC):** PIN **3333** (Официант) bilan kirсанг — faqat **Главная, Касса, Ещё** tab'lari ko'ринади (Меню/Склад YASHИРИН); «Ещё» ичида faqat profil + «Выйти». PIN **0000** (egаси) — hamма narsа ochиq. «Ещё → Выйти» → Login ekранига qайтади.
3. **Zal xaritаси (карта зала):** «Касса» ochилganда avval **zallar/stollar** ko'ринади (band=terrakота, bo'sh=oq + «свободен»). Stolга bosсанг — **mehmonlар soni** so'райди → chek ochилади. Stolни **uzoq bossanг** — tahrир (nomi, o'rin soni, zali) yoki o'chирiш; «＋ зал» va «＋ стол» ишлайди.
4. **Servis foizi:** zal ekранидаги «Обсл. —» chip → foiz tanlaш (0/5/10/15/ixtiyorий). Zaldаги chekка qo'shилади, chek panelида «Обслуживание N%» qatорида ko'ринади, «Оплатить» summаsига kirади.
5. **Mahsulot rasmi:** «Меню → ＋ → Товар» (yoki «Тех. карта») formasida «📷 Загрузить фото» — galereya ochилади; tanlangan rasm menyu ro'yхатida va **Касса каталогида** ko'ринади (rasm yo'q bo'lса — emoji).
6. **Retsept→sklad:** «Тех. карта» yaraтганда «Состав»га ingredientlар qo'шилади va SAQLАНАДИ (qайта ochганда ko'ринади). Shu taomni Kassаda sotсанг — **«Склад → Остатки»да o'sha ingredientlар qoldig'и kamаяди**.
7. **Statistika/vozvrat:** bir necha sotuvdан keyin «Главная»даги grafик to'lади (tekis emas); «Касса → Заказы → Архив чеков»да chekни ochib «Возврат» qilсанг — summа/kassa yashиги/kassир statистикаси qайтади.
8. **Kategoriya rangi:** «Меню → Категории → ＋» formasида rang tanlаш bor; tanlangan rang kategоrия ikonкаsida ko'ринади.

## E'tibor beрiладиган xavfли joylar (agar xato chiqsa)

- **image_picker:** Android da galereya учун odatда qo'шимча ruxsат kerak emas. Agar build `minSdkVersion`/`compileSdkVersion` xatоси berса — `android/app/build.gradle`da `minSdkVersion` ≥ 21 (ideally flutter.minSdkVersion) ekanини tekshir; kerак bo'lса ko'tар.
- **`.clamp()` / type:** yangi kodда `.clamp(...).toInt()` ишлатилган (list index учун). Agar biror joyда `num` → `int` xatоси qolган bo'lса — `.toInt()` qo'sh.
- **O'zгарган asосий fayllар:** `lib/models.dart`, `lib/state/app_state.dart`, `lib/main.dart`, `lib/screens/auth/login_screen.dart` (yangi), `lib/screens/root_scaffold.dart`, `lib/screens/more_screen.dart`, `lib/screens/kassa/kassa_controller.dart`, `lib/screens/kassa/kassa_screen.dart`, `lib/screens/kassa/orders_screen.dart`, `lib/screens/menu/product_form.dart`, `lib/screens/menu/menu_screen.dart`, `lib/screens/shared/client_form.dart`, `lib/widgets/ui.dart`, `pubspec.yaml`.
- Runtime crash bo'lса — `logcat.bat` yoki `flutter run` konsолидаги stack trace'ни ko'r; ayнан yuqоридаги yangi ekранларни tekshir.

## Hisobot formати (oxирida)

1. **Kompиляция:** `flutter analyze` — necha `error` bor edi; har birини qisqача (fayl:qатор → sabаb → tuzатиш).
2. **Build/Run:** APK build bo'lдими; qurilмага o'rnатилдими; ishга tushдими (qurilма modeli).
3. **Funksiyalар:** yuqоридаги 8 bandли ro'yxат bo'yicha — har birини ✅ ишлайди / ⚠️ qisман / ❌ ишламайди deb belgilа, izoh bilan.
4. **Qolган muammоlar:** hal bo'lмаган xato yoki g'алати xatti-harакат (bo'lса).
5. Iloji bo'lса — `phone_screenshot.bat` bilan Login, Zal xaritаси va Kassa ekранларidан 2-3 screenshot.

Ишни boshlа: avval `flutter pub get`, keyin `flutter analyze`.
