# POS TERMINAL — to'liq audit (try-pos, jonli)
Poster terminali planshet-ilova (iPad/Android/brauzer). Test: `/manage/try-pos` (iPad ramkasida).

## 0. PIN ekran (login)
- Logo «Poster», slogan «Больше, чем просто касса»
- 4 nuqtali PIN indikator, raqamlar 1-9/0, «Удалить», ⌫
- Pastki chap: заведение nomi («test»), «Касса в „test"», «Клиентский номер: 567053»
- O'ng past: yordam chat tugmasi. Test PIN: 0000
- Har bir xodimning o'z PIN'i bor (rol asosida huquqlar)

## 1. Asosiy savdo ekrani (Чек)
Yuqori qora panel:
- «‹ Заказы» (buyurtmalar ro'yxatiga)
- Tablar: **Чек** (✓ belgisi bilan agar to'ldirilgan) | **Клиент**
- Markaz: **«Чек №N ▾»** dropdown → ochiq cheklar ro'yxati («№1: Плов чайханский, Кока-К…») + «Создать новый» (parallel cheklar!)
- O'ng ikonkalar: 🗃 (Архив чеков shortcut) | ☰ (Функции) | «test 🔓» (kassir, bloklash) | 🟢 (onlayn indikator)

Chap panel (chek):
- Jadval: Наименование | Кол-во | Цена | Итого
- Pastda: «К оплате» + jami summa (СУМ)
- Tugmalar: [⋯] (menyu: «Комментарий к чеку…», «Очистить заказ») | [🖨] (chekni chop etish) | yashil **[Оплатить]**

O'ng panel (katalog):
- Sarlavha/breadcrumb: «Все товары › Kategoriya»
- Ikonkalar: ▮▮ (shtrix-kod skaner) | 🔍 (qidiruv) | [Акции] tugma
- Kategoriya plitkalari (foto yoki 2-harf placeholder), keyin mahsulot plitkalari (foto, nom, narx)
- Mahsulot bosilsa → chekka qo'shiladi (qayta bosilsa kol-vo +1)

## 2. Pozitsiya detali (chek qatoriga bosilganda)
O'ng panel almashinadi: «‹ Свернуть» | mahsulot nomi
- **Комментарий** (textarea) — pozitsiyaga izoh (oshxonaga boradi)
- **Количество**: [−1] [−0,5] [qiymat] [+0,5] [+1]
- (Business/Pro tarifda: skidka, modifikatorlar shu yerda)

## 3. Клиент tab
Bo'sh holat: «Здесь будут клиенты. Создавайте карточки клиентов, чтобы быстро добавлять гостей к заказам и делать скидки» + [Новый клиент] tugma
- Klient tanlansa: chekka biriktiriladi (bonus/skidka avtomatik)

## 4. ☰ Функции modali
- **Приложения**: Инвентаризация (to'q sariq ikon), Поставка (to'q sariq), «Добавить накладную с фото» (Ai — Postie AI)
- **Оборудование**: Устройства (binafsha), «Открыть денежный ящик» (binafsha)
- **Другое**: «Составить отчет», «Режим сортировки» (plitkalarni qayta tartiblash), «Очистить кеш», «Выйти из аккаунта» (kulrang ikonlar)
- ✕ yopish, sarlavha «Функции»

## 5. Составить отчет → «Отчёт по продажам» modali
- «Начиная с»: sana + vaqt (00:00), «Заканчивая»: sana + vaqt
- «Кассир»: select (Все кассиры / ...)
- «Продажи по товарам» toggle
- [Составить отчет] yashil tugma (chek printerga X-otchot chiqaradi)

## 6. To'lov ekrani (Оплатить bosilganda)
- Yuqori: «‹ Отменить» | «Чек №N»
- Chap: numpad — tez summa tugmalari [80000] [90000] (aniq va yaxlitlangan), 7 8 9 / 4 5 6 / 1 2 3 / . 0 ⌫
- O'ng: «К оплате: 80000 СУМ» (H1)
  - «Выберите способ оплаты»: qatorlar **Наличными** (💵) va **Карточкой** (💳) — har birida summa (0 СУМ); qator bosilsa qolgan summa avto-to'ldiriladi; ikkalasiga bo'lib kiritish mumkin (split payment)
  - [Сертификатом] tugma (sertifikat/gift)
  - «Напечатать чек» toggle
  - «Закрыть без оплаты» (qizil havola) | yashil **[Оплатить]**
- **Validatsiya**: summa kiritilmagan holda Оплатить bosilsa — to'lov usuli qatorlari qizil ramka bilan belgilanadi
- To'lovdan keyin: yangi bo'sh «Чек №N+1» ochiladi

## 7. Заказы ekrani («‹ Заказы»)
- Tablar: **Заказы** | **Архив чеков**; yashil [Новый заказ]; 🔍 qidiruv
- Ustunlar: Открыт | Заказ | Сумма
- Qator: «00:06 минута | 🍴 №3 › В ЗАВЕДЕНИИ | [Перейти к оплате] (ko'k tugma) | 0 СУМ ›»
- Buyurtma turlari: В заведении / (Навынос / Доставка — sozlamalarga bog'liq)

## 8. Архив чеков
- Filtr tablari: Все чеки / Наличными / Карточкой / Возвраты + «Сегодня ▾» (davr)
- Chap ro'yxat: «№ 2 — 7 СУМ — Капучино 250 мл, Круассан с шоколадом»
- O'ngda chek detali: «Чек №1» + [Чек] (yashil, chop etish) [Возврат] (kulrang, qaytarish)
  - Кассир: test; Открыт: 04 июля 2026 00:02; Счёт закрыт: 00:05
  - Jadval: Наименование|Кол-во|Цена|Итого; «Итого», «К оплате» (qalin); «Оплата: Наличными 80000 СУМ»

## 9. Bajarilgan test savdolar
- Чек №1: Плов чайханский ×2 + Кока-Кола 0,5 = 80 000 СУМ, naqd
- Чек №2: Капучино 250 мл + Круассан с шоколадом = 7 СУМ, karta

## Muhim UX naqshlari (prototip uchun)
- Plitkali katalog + doimiy ko'rinadigan chek paneli
- Parallel ochiq cheklar (dropdown orqali almashinish)
- Split to'lov, tez-summa tugmalari, chek chop etish toggle
- Oflayn indikator (yashil/qizil nuqta)
- PIN bilan tez kassir almashinuvi
- Kategoriya breadcrumb navigatsiyasi
