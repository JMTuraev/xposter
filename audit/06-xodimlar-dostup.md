# ДОСТУП (Xodimlar) moduli — audit (jonli)

## 6.1 Сотрудники (`access`)
- Jadval: Имя | Телефон | Логин | ПИН-код | Должность | Дата последнего входа | Ред.
- Demo: test / 00998997034444 / tnapster@mail.ru / **0000** / Владелец / «4 июля, 00:23»
- Forma (modal/sahifa): ism, telefon, login(email), parol, PIN-kod (kassa uchun), Должность (select), qaysi заведениеlarga kirish
- [Добавить]

## 6.2 Сессии пользователей (`access/user_sessions`)
- Jadval: Пользователь | Устройство (Windows 10) | Браузер (Chrome 149) | IP | Время входа

## 6.3 Должности (`access/role_listing`)
- Jadval: Название должности | Права доступа | Ред.
- Standart rollar: **Управляющий** (Полный доступ), **Маркетолог** (Статистика, Маркетинг), **Администратор зала** (Работа с кассой, Администрирование зала), **Официант** (Работа с кассой), **Владелец** (полный)
- Rol formasi: nom + huquqlar checkboxlari (kassa, statistika, moliya, menyu, sklad, marketing, sozlamalar...) + zarplata stavkasi (soatlik/oylik/% dan savdo)

## 6.4 Кассы (`access/pos`)
- Jadval: # | Название | Тип (Стандартная) | Заведение | Логин | Пароль | «Выход» (majburiy logout) | Ред.
- Demo: «Касса в „test"» / Стандартная / test / test296bskppjdb
- Har bir POS-terminal registratsiyasi shu yerda

## 6.5 Заведения (`access/places`)
- Jadval: # | Название | Адрес | Логин | Ред.
- Bir akkauntda bir nechta заведение (filial) bo'lishi mumkin — sahifalardagi «Заведение: test» filtri shundan

## 6.6 Интеграции (`access/integration`)
- «Ключи доступа интеграций» — API tokenlar ro'yxati
- Matn: «Токен доступа — это ключ, с помощью которого сторонние приложения работают с вашим аккаунтом через API…» + «Документация»
- Jadval: Сотрудник | Приложение | Токен доступа | Дата создания
