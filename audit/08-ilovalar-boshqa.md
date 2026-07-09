# ПРИЛОЖЕНИЯ va boshqa elementlar — audit

## 8.1 Все приложения (`/manage/applications`) — marketplace
Kategoriyalar bo'yicha ilova kartalari (nom, tavsif, narx, o'rnatishlar soni):
- **Аналитика для владельца**: «Отчёты о продажах в смартфоне» (Poster Boss)
- **Бронирование и заказы**: Poster QR (QR-menyu va otzivlar, $7/oy), Poster Site (onlayn-buyurtma sayti, $19/oy dan), QR-код на чек (bepul), Уведомления об онлайн-заказах в Telegram (bepul), Табло заказов ($7/oy), Poster Delivery Bot (Telegram-bot, $15/oy), WordPress Plugin ($15/oy), Предзаказ на банкет ($2.48/oy + $0.03 SMS), ReserveMe ($10/oy), E-app (bepul), Eatery Club…
- Postie AI Assistant alohida sidebar bandi
- Har karta: [Узнать больше] → o'rnatish sahifasi

## 8.2 Начало работы (`/manage/welcome`)
Onboarding: «Попробуйте Poster в действии» — 3 karta:
1. «Создайте позицию меню» → [Добавить тех. карту] (yashil)
2. «Протестируйте продажи» → [Сделать тестовую продажу] (kontur)
3. «Взгляните на отчёты» → [Посмотреть аналитику] (kontur)
+ video-darslar bloklari pastda. Sidebar'da «Начало работы» badge (qolgan qadamlar soni)

## 8.3 Umumiy UI naqshlari (admin)
- Chap sidebar: ikonkalar (yig'ilgan holat), hover/bosishda kengayadi; bo'limlar: 🏠 Начало работы, 📊 Статистика, 💲 Финансы, 📄 Меню, 🗂 Склад, ⏱ Маркетинг(?), 🔓 Доступ, ▦ Приложения, ⚙ Настройки; pastda 👤 profil
- Yuqori ko'k trial banner (doimiy)
- Sahifa naqshlari: sarlavha + soni badge, [Столбцы|Экспорт|Печать|Импорт] ikonkalari, yashil [Добавить], filtrlar qatori (Быстрый поиск + dropdown filtrlar + «+ Фильтр»), jadval (sortlanadigan ustunlar, hover amallar «Ред.» «⋯» «Детали»), Итого qatori, paginatsiya (100 qator)
- URL hash'ida jadval holati (ustunlar/filtr/sort/sahifa) saqlanadi — deep-linking
- Muvaffaqiyat alertlari: yashil banner sahifa tepasida («Товар сохранен», «Транзакция добавлена»…) ✕ bilan
- O'chirish: qizil tasdiqlash modali («Удалить/Отменить»)
- Yordam: o'ng pastda ko'k chat tugmasi (Intercom uslubi), kontekst yordam havolalari formalarda, «Смотреть видео» bo'sh holatlarda
- Bo'sh holatlar: illyustratsiya/emoji + sarlavha + tavsif + CTA tugma
- Sana tanlagich: preset davrlar + 2-3 oylik kalendar, «4 июня — 4 июля» format
- NPS so'rovi vaqti-vaqti bilan (0-10 baho popup)
- Promo-tooltiplar yangi funksiyalar uchun (masalan P&L)

## 8.4 Poster Boss (mobil ilova, marketing sahifadan)
- Egasi uchun: chek hisobotlari, moliya oqimi, sklad auditi, kunlik savdo
- Bizning ilovada: «Bosh sahifa» dashboard sifatida shu rolni o'ynaydi
