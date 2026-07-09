# Buxoro POS — Flutter ilova

Poster POS (joinposter.com) analogining Android/iOS ilovasi. Chaykhana «Bukhoro» (Buxoro) uchun.
Dizayn: «Claude Light» paletra (krem fon, terrakota aksent, serif sarlavhalar).
Backend YO'Q — barcha ma'lumotlar mock (xotirada), lekin interfeys to'liq interaktiv.

## Ishga tushirish (Windows, ulangan Android qurilma)

1. Flutter SDK o'rnatilgan bo'lsin: https://docs.flutter.dev/get-started/install/windows
2. Android qurilmani USB orqali ulang, «USB debugging» (Отладка по USB) ni yoqing.
3. Ushbu papkadagi **`setup_and_run.bat`** faylini ishga tushiring (ikki marta bosing).
   - U birinchi marta `android/` scaffolding'ini yaratadi, paketlarni yuklaydi va `flutter run` qiladi.

Yoki qo'lda terminalda:
```bash
cd D:\poster\buxoro_pos
flutter create --project-name buxoro_pos --org com.buxoropos --platforms=android .
flutter pub get
flutter run
```
> Eslatma: `flutter create` mavjud `lib/` va `pubspec.yaml` ni ustiga yozib yuborishi mumkin.
> `setup_and_run.bat` bu fayllarni vaqtincha nomlab, keyin qaytaradi — shuning uchun batch tavsiya etiladi.

## Bosqichlar (fable taqsimoti bo'yicha)

| Bosqich | Modul | Holat |
|---|---|---|
| 1 | Karkas + dizayn-tizim + navigatsiya + Bosh sahifa (dashboard) + Ещё | ✅ |
| 2 | Касса (POS terminal): PIN, chek, oplata, arxiv | ⏳ |
| 3 | Меню va Склад | ⏳ |
| 4 | Статистика va Финансы | ⏳ |
| 5 | Маркетинг, Сотрудники, Настройки, Подписка, Приложения | ⏳ |

## Loyiha tuzilmasi (`lib/`)

- `theme.dart` — Claude Light ranglar, shriftlar, radiuslar
- `models.dart` — data modellar (Product, Ingredient, Client, ...)
- `state/app_state.dart` — mock ma'lumotlar + holat (ChangeNotifier)
- `utils/format.dart` — summa formati (`2 480 000 СУМ`)
- `widgets/ui.dart` — qayta ishlatiladigan komponentlar (karta, tugma, badge, toast, sheet)
- `screens/` — ekranlar (home, more, kassa, menu, sklad, ...)

## PIN kodlar (Kassa)
- `0000` — Жафар (Владелец)
- `1111` — Азиз (Официант)
- `2222` — Малика (Официант)

## Muhim eslatma: `aapt` xatosi va yechim
Ushbu mashinada Android build-tools **36.1.0** dagi `aapt.exe` `flutter run` paytida
manifestni o'qishda qulab tushadi (`exit code -1073741819`). APK muvaffaqiyatli quriladi,
lekin `flutter run` uni telefonga o'rnata olmaydi.

**Ishlaydigan yechim (hozir shu ishlatildi):**
1. `setup_and_run.bat` — APK ni quradi (`build\app\outputs\flutter-apk\app-debug.apk`).
2. `install_apk.bat` — tayyor APK ni `adb` orqali telefonga o'rnatadi va ochadi
   (`aapt` ni chetlab o'tadi). ✅ Ilova telefonda ishga tushdi.

**Hot reload bilan `flutter run` uchun to'liq yechim (ixtiyoriy):**
Eski build-tools o'rnatib, uni ishlatish:
```bash
sdkmanager "build-tools;34.0.0"
```
So'ng `android/app/build.gradle.kts` da: `buildToolsVersion = "34.0.0"` qatorini qo'shing.
Shundan keyin `flutter run` hot reload bilan normal ishlaydi.
