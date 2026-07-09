# МЕНЮ moduli — to'liq audit (jonli, test296)

## 1.1 Товары (`/manage/menu`) — ro'yxat sahifasi
- Sarlavha: «Товары» + soni (badge)
- Yuqori o'ng ikonkalar: 🗑 (tanlanganlarni o'chirish), ▦ (ustunlarni sozlash), ↑ (eksport), 🖨 (chop etish), ⋯ (qo'shimcha), yashil **«Добавить»**
- Filtrlar qatori: 🔍 «Быстрый поиск», «Категория ▾», «Цех ▾», «Заведение: test ▾» (chip), «+ Фильтр»
- Jadval ustunlari: Название (rasm bilan) | Категория | Себестоимость без НДС | Цена | Наценка | «Ред.» | «⋯»
- Qator: hover'da amallar. Rasm yo'q bo'lsa nomdan 2-3 harfli kulrang placeholder (masalan «КОЛ»)
- URL'da filtr/sort/sahifa holati base64 hash sifatida saqlanadi

## 1.2 Добавление товара (`/manage/menu/product_form`)
Maydonlar:
- **Название** (matn, majburiy)
- **Категория** (select: mavjud kategoriyalar + «Добавить новую категорию…» → inline panel: nomi, ota-kategoriya select, «Фотография категории» yuklash, [Добавить] / «или отменить»)
- **Цех приготовления** (select: Без цеха / Бар / Кухня)
- **Обложка** (rasm yuklash; bo'sh bo'lsa nom bosh harflaridan avto-placeholder)
- **Опции**: ☐ Весовой товар (unit select: г), ☐ Не участвует в скидках
- **Цена и штрихкод** (radio):
  - ● Без модификаций: Штрихкод (matn), Себестоимость без НДС (raqam, СУМ) + Наценка (%) = Итого (СУМ) — uch maydon o'zaro avto-hisoblanadi
  - ○ С модификациями: har biri uchun blok {Название, Штрихкод, Себестоимость+Наценка=Итого} + «Добавить еще одну модификацию» havolasi
- O'ngda kontekst yordam havolalari («Что такое весовой товар?» va h.k.)
- Tugmalar: **[Сохранить]** (yashil) / [Сохранить и создать ещё] (kontur)
- Saqlashda: yashil banner-alert «Товар сохранен» (✕ bilan yopiladi); «создать ещё» forma tozalanadi
- Yashirin maydonlar (nomlar): product_name, menu_category_id, workshop, product_color (terminal plitka rangi), weight_flag, nodiscount, barcode, price[N]

## 1.3 Тех. карты (`/manage/dishes`)
- Jadval: Название | Категория | Выход (кг) | Себестоимость без НДС | Цена | Наценка | «Состав» | «Ред.» | «⋯»
- Kam marjali tannarx ogohlantirish rangda (to'q sariq)
- Demo: Капучино 250 мл (Кофе, 0,248 кг, 0,80→3,00, 275%), Круассан с шоколадом (Выпечка, 426%)

## 1.4 Добавление тех. карты (`/manage/dish_form`)
- Yuqori o'ngda: [🖨 Распечатать] (tex-karta blankasi)
- Maydonlar: Название; Категория; Цех приготовления (hint: «бегунки чоп этиш va turli skladlardan ingredient hisobdan chiqarish uchun»); Обложка; Опции (☐ Весовая тех. карта, ☐ Не участвует в скидках)
- **Цена** (СУМ) + o'ngda jonli hisob: «Наценка до налога: 132%», «Себестоимость без НДС: 15 080,00 СУМ» (retseptdan)
- **Дополнительно** (yig'ma): Штрихкод; Процесс приготовления (textarea); Время приготовления (мин + с)
- **Состав** bo'limi: bo'sh holatda illyustratsiya + «Заполните составляющие тех. карты…» + [+ Добавить продукт]
  - Qator ustunlari: Продукты (autocomplete select: qidiruv + «Добавить ингредиент „X"» inline yaratish) | Метод приготовления | Брутто (г/мл) | 📎 (brutto=netto bog'lash) | Нетто | Себестоимость без НДС | ✕
  - Pastda: «+ Добавить ингредиент», «Выход: 460 г», «Итого: 15 080,00 СУМ» — jonli hisob
- **Модификаторы** bo'limi: «+ Добавить набор модификаторов…» + yashil badge «Модификаторы доступны только в тарифах Business и Pro» (tarif cheklovi!)
- [Сохранить] / [Сохранить и создать ещё]; muvaffaqiyat: «Тех. карта сохранена»

## 1.5 Полуфабрикаты (`/manage/prepack`)
- Jadval: Название | Выход | Себестоимость. Forma tex-kartaga o'xshash (retsept, lekin narxsiz — yarim tayyor mahsulot)

## 1.6 Ингредиенты (`/manage/ingredients`)
- Jadval: Название | Категория | Ед. измерения | Потери (5 ustun %) | Остатки на складах | Себестоимость | Сумма остатков | «Детали» | «Ред.» | «⋯»
- Itogo qatori pastda. Ikonkalar: ▦, ↑ eksport, ↓ import(!), 🖨. «Добавить»
- Filtr: qidiruv, Категория, Ед. измерения, + Фильтр

## 1.7 Добавление ингредиента (`/manage/menu/ingredient_form`)
- Название; Ед. измерения (шт./кг/л)
- «Дополнительно» (yig'ma): Штрихкод; % потерь при: очистке/варке/жарке/тушении/запекании; (шт uchun: вес одной штуки, частичное списание: Округлять/Без округления)
- **Складской учет** bloki: «Кол-во в наличии» (+birlik), «Цена за кг» (СУМ), «Склад» (select) — saqlashda Poster avtomatik "Поставка" yaratadi!
- [Сохранить]; muvaffaqiyat: «Ингредиент сохранён»
- Demo ingredientlar (13): Бумажные стаканы 250мл, Вода, Дрожжи, Кофе, Крышка 250мл, Масло сливочное, Молоко, Мука, Размешиватель, Сахар, Соль, Шоколад черный, Яйцо
- Men qo'shganlar (6): Рис лазер 20кг@18000, Морковь жёлтая 15@5000, Говядина 20@90000, Лук репчатый 10@4000, Масло растительное 10л@22000, Чай чёрный (сухой) 2@80000

## 1.8 Категории товаров и тех. карт (`/manage/menu/categories_products`)
- Daraxt ro'yxat: Название | har qatorda «Ред. / Скрыть / Удалить / Отменить»
- Kategoriyalar: Кофе, Выпечка, Холодные напитки, Основные блюда (+ ota «Главный экран»)

## 1.9 Категории ингредиентов (`/manage/menu/categories_ingredients`) — o'xshash daraxt

## 1.10 Цехи (`/manage/workshops`)
- Jadval: Название | Печатать бегунки (Да/Нет) | Ред.
- Qatorlar: Бар (Да), Кухня (Да). Tugmalar: [Добавить], [Применить]
- Цех = oshxona stansiyasi; buyurtma pozitsiyalari tegishli printerga «бегунок» bo'lib boradi

## Yaratilgan mock data (Poster ichida)
- Товар: Кока-Кола 0,5 л (Холодные напитки, 5000+100%=10000 СУМ)
- Товар: Лепёшка тандырная (Выпечка, 2000+100%=4000 СУМ)
- Тех. карта: Плов чайханский (Основные блюда, Кухня; retsept: Рис 150г, Говядина 120г, Морковь 100г, Лук 50г, Масло раст. 40мл; Выход 460г; себест. 15 080; narx 35 000; наценка 132%)
- Kategoriya: Основные блюда (inline yaratildi)

## 404 sahifa
Katta «4🙁4» + «Мы сделали всё, что могли, но так и не нашли эту страницу на сайте»
