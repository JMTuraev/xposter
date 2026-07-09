# ФИНАНСЫ moduli — audit (jonli)

## 3.1 Транзакции (`finance/transactions`)
- Yuqori: [▦ Столбцы] [↑ Eksport] [🖨] + [За все время ▾] (davr) + **[Импорт с AI ✨]** (Postie: bank vypiskasini yuklash) + yashil [Добавить]
- Filtr: Быстрый поиск, Категория ▾, Счет ▾, + Фильтр
- Jadval: Дата | Категория (▾ inline o'zgartirish) | Комментарий | Сумма (chiqim qizil «−500 000,00 СУМ») | Счет | Ред. | ⋯; pastda Итого qatori
- Bo'sh holat: 💸 illyustratsiya «Здесь будут транзакции» + tushuntirish + «расходную транзакцию» havola + «▶ Смотреть видео»

### «Добавить транзакцию» modali
- **Тип**: tab-tugmalar [Расход (ko'k aktiv) | Доход | Перевод]
- **Сумма**: input, chiqimda «−» prefiks, o'ngda СУМ
- **Со счета**: select (Расходда) / «На счёт» (Доходда) / ikkalasi (Переводда)
  - Schyotlar: «Денежный ящик для „test"», «Расчетный счет», «Сейф»
- **Категория**: qidiruvli select (Актуализация, Банковские услуги и комиссии, Хозяйственные расходы, Зарплата, Маркетинг, Аренда, Поставки, Коммунальные платежи…)
- **Дата транзакции**: sana + soat:daqiqa (00:14)
- **«Другая дата сделки»** toggle (ⓘ) — hisobot davri boshqa bo'lsa
- **Комментарий**: input
- [Сохранить] [Отменить]; muvaffaqiyat: yashil «Транзакция добавлена»

## 3.2 Cash flow (`finance/cashflow`)
Pul oqimi hisoboti: davr bo'yicha Поступления/Выбытия kategoriya kesimida, davr boshi/oxiri qoldiq. (Ma'lumot kam bo'lgani uchun bo'sh ko'rindi)

## 3.3 Кассовые смены (`finance/cash_shift`)
- [Распечатать], davr tanlagich
- Jadval: # | Смена открыта | Смена закрыта | Начало смены | Инкассация | В кассе | Разница
- Holat xabari: «Учёт кассовых смен отключён — Чтобы включить учёт кассовых смен, воспользуйтесь переключателем „Кассовые смены" во вкладке „Настройки"» (ya'ni smena hisobi sozlamalardan yoqiladi)

## 3.4 Зарплата (`finance/salary`)
- Filtr: Должность; ustunlar: Должность | Смены | Итого
- Bo'sh holat: «Poster автоматически рассчитает зарплату для ваших сотрудников. Для этого настройте учет рабочего времени и укажите ставки по должностям»
- (Stavkalar Доступ→Должности da: soatlik/oylik/% savdodan)

## 3.5 Счета (`finance/accounts`)
- Jadval: Название | Тип | Баланс | Ред.
- Standart: Денежный ящик для «test» (Наличные, 0), Расчетный счет (Безналичный счет, −500 000 test chiqimim), Сейф (Наличные, 0)
- [Добавить] — yangi schyot (nomi, turi: Наличные/Безналичный)

## 3.6 Категории (`finance/categories`)
- Jadval: Название | Допустимые транзакции (Все транзакции/Только расходы/Только доходы) | Отображать на кассе (checkbox) | Отображать в P&L | Ред.
- Standart 13: Актуализация, Банковские услуги и комиссии, Пополнение депозитных счетов, Хозяйственные расходы, Зарплата, Маркетинг, Аренда, Поставки, Коммунальные платежи, Кассовые смены, (va b.)
- [Добавить]

## 3.7 P&L (`finance/pnl`)
- Aktivlashtirilmagan holatda: sariq banner «Это пример того, как может выглядеть ваш отчет P&L…» + [Подключить]
- Demo jadval: oylar ustunlari (usd + %):
  - ∨ Доходы → Продажи товаров и тех. карт (100%)
  - ∨ Себестоимость → Себестоимость проданных товаров и тех. карт
  - **Маржа** (qalin)
  - ∨ Расходы → Аренда, Банковские услуги и комиссии, Зарплата, Коммунальные платежи, Маркетинг…
  - (davomida: Операционная прибыль va h.k.)
- O'ng panelda maslahat-karta: «Себестоимость выросла. Может пришло время поднять цены?»
- [Столбцы] [Экспорт] + davr

## Yaratilgan mock data
- Rasxod tranzaksiyasi: −500 000 СУМ, Аренда, «Аренда помещения за июль», Расчетный счет
