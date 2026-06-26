-- ============================================================
--  РМС — схема БД для Render (PostgreSQL 14+)
--  Запустіть в Render Dashboard → PostgreSQL → Shell
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 1. ПОСТИ ─────────────────────────────────────────────────
CREATE TABLE posts (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name       VARCHAR(128) NOT NULL,
    location   VARCHAR(256),
    region     VARCHAR(128),
    latitude   NUMERIC(9,6),
    longitude  NUMERIC(9,6),
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_posts_region    ON posts(region);
CREATE INDEX idx_posts_is_active ON posts(is_active);

-- ── 2. КОРИСТУВАЧІ (перед alarms!) ──────────────────────────
CREATE TYPE user_role AS ENUM ('admin', 'operator', 'guest');

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username      VARCHAR(64)  NOT NULL UNIQUE,
    email         VARCHAR(256) NOT NULL UNIQUE,
    password_hash VARCHAR(256) NOT NULL,
    role          user_role    NOT NULL DEFAULT 'guest',
    post_id       UUID REFERENCES posts(id) ON DELETE SET NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    last_login    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_users_role    ON users(role);
CREATE INDEX idx_users_post_id ON users(post_id);

-- ── 3. ПРИЛАДИ ───────────────────────────────────────────────
CREATE TYPE device_type AS ENUM ('PFU', 'PAED_GAMMA', 'SPECTROMETER');

CREATE TABLE devices (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id     UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    type        device_type NOT NULL,
    name        VARCHAR(128),
    serial_port VARCHAR(64),
    baud_rate   INTEGER DEFAULT 9600,
    is_online   BOOLEAN NOT NULL DEFAULT FALSE,
    last_seen   TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_devices_post_id   ON devices(post_id);
CREATE INDEX idx_devices_is_online ON devices(is_online);

-- ── 4. ВИМІРЮВАННЯ (без партицій для сумісності) ────────────
CREATE TABLE measurements (
    id          BIGSERIAL PRIMARY KEY,
    post_id     UUID NOT NULL,
    device_id   UUID NOT NULL,
    parameter   VARCHAR(64) NOT NULL,
    value       NUMERIC(18,6) NOT NULL,
    unit        VARCHAR(32) NOT NULL,
    quality     SMALLINT DEFAULT 0,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    synced      BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_meas_post_time   ON measurements(post_id,   recorded_at DESC);
CREATE INDEX idx_meas_device_time ON measurements(device_id, recorded_at DESC);
CREATE INDEX idx_meas_parameter   ON measurements(parameter, recorded_at DESC);

-- ── 5. АВАРІЇ ────────────────────────────────────────────────
CREATE TYPE alarm_level  AS ENUM ('INFO', 'WARNING', 'CRITICAL');
CREATE TYPE alarm_status AS ENUM ('ACTIVE', 'RESOLVED', 'IGNORED');

CREATE TABLE alarms (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id      UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    device_id    UUID REFERENCES devices(id) ON DELETE SET NULL,
    level        alarm_level  NOT NULL DEFAULT 'WARNING',
    status       alarm_status NOT NULL DEFAULT 'ACTIVE',
    message      TEXT NOT NULL,
    threshold    NUMERIC(18,6),
    actual_value NUMERIC(18,6),
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at  TIMESTAMPTZ,
    resolved_by  UUID REFERENCES users(id) ON DELETE SET NULL,
    notes        TEXT
);
CREATE INDEX idx_alarms_status    ON alarms(status);
CREATE INDEX idx_alarms_triggered ON alarms(triggered_at DESC);

-- ── 6. ПОРОГОВІ ЗНАЧЕННЯ ─────────────────────────────────────
CREATE TABLE thresholds (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id     UUID REFERENCES posts(id) ON DELETE CASCADE,
    device_type device_type NOT NULL,
    parameter   VARCHAR(64) NOT NULL,
    warn_value  NUMERIC(18,6) NOT NULL,
    crit_value  NUMERIC(18,6) NOT NULL,
    unit        VARCHAR(32),
    created_by  UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 7. ТРИГЕР updated_at ─────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_posts_updated_at
    BEFORE UPDATE ON posts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_thresholds_updated_at
    BEFORE UPDATE ON thresholds FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ── 8. ТЕСТОВІ ДАНІ ──────────────────────────────────────────
INSERT INTO posts (name, location, region, latitude, longitude) VALUES
    ('Пост №1', 'вул. Хрещатик 1, Київ',     'Київська область',   50.4501, 30.5234),
    ('Пост №2', 'вул. Соборна 15, Харків',    'Харківська область', 49.9935, 36.2304),
    ('Пост №3', 'вул. Дерибасівська 3, Одеса','Одеська область',    46.4825, 30.7233);

-- Паролі встановіть через set_admin_password.py після деплою
INSERT INTO users (username, email, password_hash, role) VALUES
    ('admin',     'admin@example.com',    'TEMP', 'admin'),
    ('operator1', 'op1@example.com',      'TEMP', 'operator'),
    ('guest1',    'guest1@example.com',   'TEMP', 'guest');

INSERT INTO thresholds (device_type, parameter, warn_value, crit_value, unit) VALUES
    ('PAED_GAMMA',   'dose_rate', 0.30,   1.20, 'мкЗв/год'),
    ('SPECTROMETER', 'activity',  100.00, 500.00, 'Бк/м³'),
    ('PFU',          'flow_rate', 0.50,   0.10,  'м³/год');
