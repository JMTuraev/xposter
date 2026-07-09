# СКЛАД (Ombor) moduli — audit (jonli)

Umumiy: har sahifada [Столбцы] [Экспорт] [Печать] + davr + [Добавить] (yashil). Filtrlar kontekstga mos.

## 4.1 Остатки (`calculations`)
- Jadval: Название | Тип (Ингредиент/Товар) | Категория | Остатки | Себестоимость | Сумма | Лимит | «Поставки» (havola)
- **Jonli tekshiruv**: savdodan keyin avtomatik hisobdan chiqarilgan — Бумажные стаканы 100→99 шт (kapuchino retsepti!), Вода 10→9,960 л
- Лимит — minimal qoldiq ogohlantirishi (0 = o'rnatilmagan)

## 4.2 Поставки (`calculations/supply`)
- Jadval: № | Дата | Поставщик | Склад | Счет | Товары (ro'yxat) | Комментарий | Статус | Сумма | Задолженность
- Ingredient yaratishda «Складской учет» to'ldirilsa avto-поставка hosil bo'ladi (поставщик «Закупка»)

### Добавление поставки (`calculations/supply/form`)
- Дата и время поставки (sana + HH:MM)
- Поставщик (select), Склад (select)
- **Оплата**: «+Добавить платеж» (schyot tanlash + summa; to'lanmasa — задолженность)
- Комментарий (textarea)
- **Импорт поставки**: CSV/XLS/XLSX drag&drop zona (nomlar mosligini tekshirish haqida eslatma)
- Pozitsiyalar jadvali: Наименование (autocomplete) | Фасовки | Количество | Цена | Общая
- Pastki panel: [Сохранить] + «К оплате: X СУМ» (qizil) «Итого: X СУМ»; [Печать]

## 4.3 Списания (`calculations/waste`)
- Tablar: **Список | Причины** (sabablar spravochnigi)
- Filtr: Склад, Категории, Причина
- Jadval: Дата | Склад | Товары | Сумма | Сотрудник | Причина
- Forma: sana, sklad, sabab (select), pozitsiyalar (mahsulot+miqdor), izoh

## 4.4 Перемещения (`calculations/moving`)
- Jadval: Дата | Наименование | Сумма | Сотрудник | Склады (qayerdan→qayerga)

## 4.5 Переработки (`calculations/butcheries`)
- Jadval: Дата | Исходные продукты | Полученные продукты (masalan: butun go'sht → bo'laklar)

## 4.6 Отчёт по движению (`calculations/reports`)
- Jadval: Название | Тип | Нач. остаток | Средняя себест. на начало | Нач. сумма | Поступления | Расход | Итог. остаток | Средняя себест. на конец | Итог. сумма

## 4.7 Инвентаризации (`calculations/inventory`)
- Jadval: Склад | Начало периода | Дата и время проведения | Тип (Полная/Частичная) | Результат (недостача/излишек) | Статус (Черновик/Проведена)
- Bo'sh holat: «Добавьте инвентаризацию — Чтобы сравнить планируемые и фактические остатки продуктов на складе…»
- Forma: sklad, sana, tur; jadval: mahsulot | plan qoldiq | fakt qoldiq (kiritiladi) | farq | summa

## 4.8 Поставщики (`calculations/suppliers`)
- Jadval: Имя | Телефон | Адрес | Комментарий | Количество поставок | Сумма поставок | Сумма задолженности | Ред.; Итого qatori
- Demo: «Закупка» — 3 поставки, 2 655 215,20 СУМ, задолженность 2 655 000 СУМ (to'lov biriktirilmagani uchun)

## 4.9 Склады (`calculations/storages`)
- Jadval: # | Название | Адрес | Сумма | Ред.; Итого
- Demo: Склад 1 = 2 625 053,47 СУМ

## 4.10 Фасовки (`calculations/packing`)
- Jadval: Название | Ед. измерения | Количество; bo'sh holat «Фасовок еще нет — Фасовки помог[ают]…» (qadoq birliklari: masalan «yashik = 12 sht»)
