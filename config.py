# core/config.py — налаштування проєкту (змінні середовища)

import os

# ── База даних ───────────────────────────────────────────────
# На Render: DATABASE_URL автоматично встановлюється PostgreSQL сервісом
# Формат: postgresql://user:password@host:port/dbname
_DATABASE_URL = os.environ.get("DATABASE_URL", "")

if _DATABASE_URL:
    # Парсимо DATABASE_URL → DB_CONFIG
    import re
    _m = re.match(
        r"postgres(?:ql)?://([^:]+):([^@]+)@([^:/]+):?(\d+)?/(.+)",
        _DATABASE_URL
    )
    if _m:
        DB_CONFIG = {
            "host":     _m.group(3),
            "port":     int(_m.group(4) or 5432),
            "dbname":   _m.group(5),
            "user":     _m.group(1),
            "password": _m.group(2),
        }
    else:
        DB_CONFIG = {"dsn": _DATABASE_URL}
else:
    # Fallback для локальної розробки
    DB_CONFIG = {
        "host":     os.environ.get("DB_HOST",     "localhost"),
        "port":     int(os.environ.get("DB_PORT", "5432")),
        "dbname":   os.environ.get("DB_NAME",     "radiation_monitoring"),
        "user":     os.environ.get("DB_USER",     "postgres"),
        "password": os.environ.get("DB_PASSWORD", ""),
    }

# ── JWT ──────────────────────────────────────────────────────
SECRET_KEY           = os.environ.get("SECRET_KEY", "change-me-in-production-please")
ALGORITHM            = "HS256"
TOKEN_EXPIRE_MINUTES = int(os.environ.get("TOKEN_EXPIRE_MINUTES", "480"))  # 8 годин

# ── Gmail SMTP ───────────────────────────────────────────────
GMAIL_USER    = os.environ.get("GMAIL_USER",    "")
GMAIL_PASS    = os.environ.get("GMAIL_PASS",    "")
_emails       = os.environ.get("NOTIFY_EMAILS", "")
NOTIFY_EMAILS = [e.strip() for e in _emails.split(",") if e.strip()]

# ── Telegram бот ─────────────────────────────────────────────
TELEGRAM_TOKEN  = os.environ.get("TELEGRAM_TOKEN",  "")
_chat_ids       = os.environ.get("NOTIFY_CHAT_IDS", "")
NOTIFY_CHAT_IDS = [int(c.strip()) for c in _chat_ids.split(",") if c.strip()]

# ── Сповіщення ───────────────────────────────────────────────
NOTIFY_MIN_LEVEL    = os.environ.get("NOTIFY_MIN_LEVEL",    "WARNING")
NOTIFY_COOLDOWN_MIN = int(os.environ.get("NOTIFY_COOLDOWN_MIN", "30"))
