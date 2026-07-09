# СТАТИСТИКА moduli — audit (jonli, savdo ma'lumotlari bilan)

Umumiy naqsh: har sahifada yuqori o'ngda [Столбцы ▦] [Экспорт] [Печать] + sana-diapazon tanlagich «4 июня — 4 июля ⇕» (kalendar: 2 oylik ko'rinish, preset davrlar). URL'da sana: /dash/stat/{d-m-yyyy}/{d-m-yyyy}.

## 2.1 Продажи (`dash/stat`) — bosh dashboard
- Sarlavha «Статистика продаж» + [Экспорт] [Печать] + davr tanlagich
- **«Сегодня, 4 июля»** karta-qator: выручка / прибыль / чека / посетителя / средний чек — har birida +100% o'sish belgisi (kechagiga nisbatan)
- **Выручка** grafigi: toggle [День|Неделя|Месяц], chiziqli grafik (nuqtalar bilan)
- Grafik ostida 5 KPI-tab (bosilsa grafik metrikasi almashadi): выручка, прибыль, чека, посетителя, средний чек
- **Методы оплаты** bloki: gorizontal barlar — Наличные / Карточка / Бонусы + summalar; toggle «Оборот|Чеки»; «Показать все»
- **По времени**: soatlik ustunli grafik (0–23)
- **По дням недели**: Пн–Вс ustunli grafik
- **Популярные товары**: 2 ustunli jadval (Товар | Заказы, «шт.»)
- Jonli test: выручка 80 007 СУМ, прибыль 49 845,44 СУМ (avto food-cost hisobi), 2 чека, средний чек 40 003,50

## 2.2 Клиенты (`dash/clients`)
- Filtrlar: Название источника, Пол, Группа
- Jadval: Клиент | Телефон | Без скидки | Наличными | Карточкой | Прибыль | Чеки | Средний чек
- Bo'sh holat: «Здесь будет статистика покупок клиентов»

## 2.3 Сотрудники (`dash/waiters`)
- Filtr: Официант, Название источника
- Jadval: Официант | Выручка | Прибыль | Чеки | Средний чек | Среднее время (chek yopish vaqti)

## 2.4 Цехи (`dash/workshops`)
- Jadval: Цех | Поштучные товары и тех. карты | Весовые | Выручка | Себестоимость | Прибыль

## 2.5 Категории (`dash/category`)
- Jadval: Категории | Кол-во | Себестоимость | Выручка | Сумма налога | Прибыль | **Food cost** (%)

## 2.6 Товары (`dash/products`)
- Filtrlar: Категории, Цех, Официант
- Jadval: Товар | Модификатор | Кол-во | Валовый оборот | Скидка | Выручка | Прибыль

## 2.7 ABC-анализ (`dash/abc`)
- Filtrlar: Все официанты, Все категории; [Распечатать]
- Jadval: # | Товар | Продажи | Продажи,% | Выручка | Выручка,% | Прибыль | Прибыль,% + ABC guruh belgilari (A/B/C rangli)
- Mohiyat: mahsulotlarni savdo/tushum/foyda bo'yicha A(top)/B/C sinflarga ajratadi

## 2.8 Чеки (`dash/receipts`)
- Filtrlar: Официант, Оплаты, Статус, Онлайн-заказы, + Фильтр
- Jadval: # | Официант | Открыт | Закрыт | Оплачено | Скидка в чеке | Прибыль | Статус (Открыт/Закрыт) | «Детали»
- «Детали» → chek tarkibi (pozitsiyalar, to'lovlar)

## 2.9 Отзывы (`dash/feedbacks`)
- Bo'sh holat: «Здесь будут отзывы гостей. Подключите приложение Poster QR, чтобы по QR-коду ваши гости оставляли обратную связь о блюдах и сервисе» + [Попробовать]
- (QR ilova ulangach: baholar ro'yxati)

## 2.10 Оплаты (`dash/payments`)
- Jadval: Дата | Количество чеков | Наличными | Карточкой | Всего (kunlik kesim)

## 2.11 Налоги (`dash/taxes`)
- Jadval: Название | Тип | Процент | Сумма товаров | Сумма налога; «Налог не указан» qatori; Итого qator
