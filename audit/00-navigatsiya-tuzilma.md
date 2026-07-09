# Poster Admin Panel — To'liq navigatsiya xaritasi
Manba: test296.joinposter.com (2026-07-03 jonli audit)

Chap sidebar (ikonkali, ochilganda bo'lim nomlari). Yuqorida: trial banner («Пробный период заканчивается ... Оплатить»).
Pastda: profil menyusi. O'ng pastda: yordam chati (Intercom uslubidagi ko'k tugma).

## 1. Начало работы (`/manage/welcome`)
Onboarding: 3 karta — «Создайте позицию меню» (Добавить тех. карту), «Протестируйте продажи» (Сделать тестовую продажу → try-pos), «Взгляните на отчёты» (Посмотреть аналитику). + video bloklar.

## 2. Статистика (`/manage/dash/*`)
| Sahifa | Path |
|---|---|
| Продажи (asosiy dashboard) | dash/stat/{dan}/{gacha} |
| Клиенты | dash/clients |
| Сотрудники | dash/waiters |
| Цехи | dash/workshops |
| Категории | dash/category |
| Товары | dash/products |
| ABC-анализ | dash/abc |
| Чеки | dash/receipts |
| Отзывы | dash/feedbacks |
| Оплаты | dash/payments |
| Налоги | dash/taxes |

## 3. Финансы (`/manage/finance/*`)
Транзакции, Cash flow, Кассовые смены (cash_shift), Зарплата (salary), Счета (accounts), Категории, P&L

## 4. Меню
Товары (`/manage/menu`), Тех. карты (`/manage/dishes`), Полуфабрикаты (`/manage/prepack`), Ингредиенты (`/manage/ingredients`), Категории товаров и тех. карт (menu/categories_products), Категории ингредиентов (menu/categories_ingredients), Цехи (`/manage/workshops`)

## 5. Склад (`/manage/calculations/*`)
Остатки (calculations), Поставки (supply), Переработки (butcheries), Перемещения (moving), Списания (waste), Отчёт по движению (reports), Инвентаризации (inventory), Поставщики (suppliers), Склады (storages), Фасовки (packing)

## 6. Маркетинг (`/manage/marketing/*`)
Клиенты, Группы клиентов, Программы лояльности, Исключения (nodiscount), Акции (promotions)

## 7. Доступ (`/manage/access/*`)
Сотрудники (access), Сессии пользователей (user_sessions), Должности (role_listing), Кассы (pos), Заведения (places), Интеграции (integration)

## 8. Приложения (`/manage/applications`)
Все приложения (marketplace), Postie AI Assistant

## 9. Настройки (`/manage/settings/*`)
Общие (settings), Заказы (order_sources), Доставка (delivery), Безопасность (security), Чек (receipt), Подписка/Оплата (settings/payments)

## 10. POS Terminal
`/manage/try-pos` — brauzer terminali (aslida alohida planshet-ilova)

## Poster mahsulot oilasi (marketing saytidan)
- POS terminal (iPad/Android/brauzer) — oflayn ishlaydi
- Management console (admin panel, brauzer)
- Poster Boss — egasi/menejer uchun mobil ilova (hisobotlar, moliya, ombor auditi)
- Postie AI — nakladnoy fotosi → Поставка; bank vypiska → Транзакции
- Kitchen Kit — oshxona displeyi (KDS)
- Poster Shop — onlayn-menyu/dostavka sayti
- QR-menyu, stol yonida to'lov, otzivlar
- Poster Connect — franshiza boshqaruvi
- Integrations + open API
