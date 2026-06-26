# 🚀 Деплой РМС на Render.com — покрокова інструкція

## Що розгортаємо

| Компонент | Де | Безкоштовно |
|-----------|-----|-------------|
| FastAPI сервер | Render Web Service | ✅ |
| PostgreSQL | Render Managed DB | ✅ (90 днів, потім $7/міс) |
| Колектор TCP | **Залишається локально** | — |

> ⚠️ **Важливо:** Колектор (`collector.py`) підключається до фізичних приладів через TCP,
> тому він має залишатися на локальному ПК або сервері поряд з приладами.
> В хмарі розгортається лише **веб-інтерфейс і API**.

---

## Крок 1 — Підготовка GitHub репозиторію

1. Зайдіть на [github.com](https://github.com) → New repository → назвіть `rms-server`
2. Завантажте файли з такою структурою:

```
rms-server/
├── main.py
├── requirements.txt          ← з цього пакету
├── render.yaml               ← з цього пакету
├── schema_render.sql         ← з цього пакету
├── core/
│   ├── __init__.py           ← порожній файл
│   ├── config.py             ← ЗАМІНЕНИЙ (з цього пакету!)
│   ├── auth.py
│   ├── database.py
│   └── notifications.py
├── routers/
│   ├── __init__.py           ← порожній файл
│   ├── auth.py
│   ├── posts.py
│   ├── measurements.py
│   ├── alarms.py
│   ├── thresholds.py
│   ├── users.py
│   └── ws.py
└── static/
    └── index.html
```

> 🔴 **Використовуйте НОВИЙ `core/config.py`** з цього пакету — він читає змінні середовища
> замість жорстко прописаних паролів!

---

## Крок 2 — Реєстрація та деплой на Render

1. Зайдіть на [render.com](https://render.com) → Sign Up (через GitHub)

2. **New → PostgreSQL**
   - Name: `rms-postgres`
   - Database: `radiation_monitoring`
   - User: `rms_user`
   - Region: Frankfurt (EU)
   - Plan: **Free**
   - → **Create Database**
   - Скопіюйте **Internal Database URL** (знадобиться)

3. **New → Web Service**
   - Connect your GitHub repo → `rms-server`
   - Name: `rms-server`
   - Runtime: **Python 3**
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - Plan: **Free**

---

## Крок 3 — Змінні середовища (Environment Variables)

В налаштуваннях Web Service → **Environment**:

| Змінна | Значення |
|--------|----------|
| `DATABASE_URL` | Internal Database URL з кроку 2 |
| `SECRET_KEY` | Будь-який довгий рядок (напр. `rms-secret-2026-xK9mP`) |
| `TELEGRAM_TOKEN` | Ваш токен бота |
| `NOTIFY_CHAT_IDS` | `692590616` |
| `NOTIFY_MIN_LEVEL` | `WARNING` |
| `NOTIFY_COOLDOWN_MIN` | `30` |

Якщо хочете email-сповіщення:

| Змінна | Значення |
|--------|----------|
| `GMAIL_USER` | `your@gmail.com` |
| `GMAIL_PASS` | App Password (16 символів) |
| `NOTIFY_EMAILS` | `admin@example.com,op@example.com` |

---

## Крок 4 — Ініціалізація бази даних

1. Render Dashboard → **rms-postgres** → **Shell**
2. Вставте вміст файлу `schema_render.sql` і виконайте

---

## Крок 5 — Встановлення паролів

Після першого деплою відкрийте Render → Web Service → **Shell**:

```bash
python set_admin_password.py
```

Або через API (POST `/api/auth/login`):
```json
{"username": "admin", "password": "admin123"}
```

---

## Крок 6 — Налаштування колектора для хмарного сервера

Відредагуйте `collector.py` на локальному ПК — замініть DB_CONFIG:

```python
# collector.py — замініть DB_CONFIG на підключення до Render
DB_CONFIG = {
    "host":     "dpg-xxxx.frankfurt-postgres.render.com",  # ← External hostname
    "port":     5432,
    "dbname":   "radiation_monitoring",
    "user":     "rms_user",
    "password": "xxxx",   # ← з Render Dashboard
    "sslmode":  "require", # ← обов'язково для Render!
}
```

> Використовуйте **External Database URL** (не Internal) для підключення ззовні Render.

---

## Результат

- 🌐 **Веб-інтерфейс:** `https://rms-server.onrender.com`
- 🔌 **API:** `https://rms-server.onrender.com/api/`
- 📡 **WebSocket:** `wss://rms-server.onrender.com/ws/live`
- 💻 **Колектор:** локально, підключається до Render PostgreSQL

> ⏱️ На безкоштовному плані сервер "засинає" після 15 хв бездіяльності
> і потребує ~30 секунд для "пробудження" при першому запиті.
> Для виробничого використання рекомендується план Starter ($7/міс).

---

## Оновлення після змін

Render автоматично перебудовує сервіс при кожному `git push` до main гілки:

```bash
git add .
git commit -m "update"
git push
```
