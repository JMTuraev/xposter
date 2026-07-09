# МАРКЕТИНГ moduli — audit (jonli)

## 5.1 Клиенты (`marketing/clients`)
- Ikonkalar: 🗑 Корзина | ▦ | ↑ Eksport | ↓ **Импорт** (CSV/XLS/XLSX) | 🖨 | [Добавить]
- Filtr: Быстрый поиск, Группа, +Фильтр
- Jadval: ФИО | Номер карты | Телефон | Группа | % | Сумма покупок
- Bo'sh holat: 🙋‍♀️🙋‍♂️ emoji «Клиентов еще нет — Добавьте ваших клиентов в систему и вознаграждайте их бонусами, скидками и акциями…»

### Добавление карточки клиента (`marketing/add_client`)
- ФИО клиента; Пол (toggle: Мужской|Женский); Дата рождения (31.12.1980 format)
- Группа (select: «Новые клиенты (0%, скидочная система)»)
- Номер карты; Персональная скидка,% («нет» placeholder)
- Номер телефона: davlat kodi select (**Узбекистан +998** default!) + raqam
- E-mail; Комментарий
- **Адрес** bloki: Страна, Город, Улица и номер дома, Дополнительно (подъезд, этаж, квартира), Комментарий + «+ Добавить адрес» (bir nechta manzil — dostavka uchun)
- [Добавить]

## 5.2 Группы клиентов (`marketing/groups`)
- Jadval: Название | Программа лояльности (скидочная/бонусная система) | % | Ред.
- Default: «Новые клиенты — скидочная система — 0%»
- Forma: nom, tur (skidka/bonus), foiz

## 5.3 Программы лояльности (`marketing/loyalty`)
Bitta sozlama sahifasi, 2 blok:
- **Бонусная система**: tushuntirish matni; Максимальный % (checkning necha %ini bonus bilan to'lash mumkin, default 50); Приветственный бонус, СУМ (registratsiya bonusi); Переход между группами (есть/нет select); Условия перехода: «от [100 СУМ] → [Выберите группу]» qatorlari + «Добавить»
- **Скидочная система**: xuddi shu tuzilma (Переход между группами: нет)

## 5.4 Исключения (`marketing/nodiscount`)
- **Категории-исключения**: «bonus bilan to'lash va skidkalar amal qilmaydigan, lekin aksiyalar qo'llanadigan» kategoriyalar jadvali (Категория | Подкатегории) + [Добавить]
- **Товары-исключения**: xuddi shu, alohida tovarlar uchun

## 5.5 Акции (`marketing/promotions`)
- Jadval: Название | Дата начала | Дата окончания | Начисление бонусов; filtr: Дата окончания
- Forma (ma'lum tuzilma): nom, davr, shartlar (mahsulot sotib olganda / summadan oshganda), natija (chegirma % / bonus / sovg'a mahsulot «Купи X — получи Y»), qaysi kunlar/soatlarda amal qilishi

## Yaratilgan mock data
- Klient: Азиз Каримов, +998 901234567, «Новые клиенты» guruhi
