#!/bin/bash
set -euo pipefail

# Seed script for demo data
# - SAFE TO RE-RUN (idempotent): uses CREATE TABLE IF NOT EXISTS + INSERT ... ON CONFLICT/WHERE NOT EXISTS
# - Does NOT drop tables / does NOT wipe data

DB_URL="postgresql://appuser:dbuser123@localhost:5001/myapp"

echo "Seeding demo schema + data into ${DB_URL} ..."

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"

# -----------------------------
# Tables
# -----------------------------
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
CREATE TABLE IF NOT EXISTS assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_tag TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  asset_type TEXT NOT NULL,
  location TEXT,
  health_score INTEGER NOT NULL CHECK (health_score >= 0 AND health_score <= 100),
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
CREATE TABLE IF NOT EXISTS inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  inspector_name TEXT NOT NULL,
  inspection_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes TEXT,
  observed_health_score INTEGER CHECK (observed_health_score >= 0 AND observed_health_score <= 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
CREATE TABLE IF NOT EXISTS alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  severity TEXT NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  alert_type TEXT NOT NULL DEFAULT 'low_health',
  message TEXT NOT NULL,
  health_score_at_alert INTEGER CHECK (health_score_at_alert >= 0 AND health_score_at_alert <= 100),
  is_acknowledged BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
CREATE TABLE IF NOT EXISTS work_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  alert_id UUID REFERENCES alerts(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  priority TEXT NOT NULL CHECK (priority IN ('P1','P2','P3')),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','completed','cancelled')),
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS idx_inspections_asset_id ON inspections(asset_id);"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS idx_alerts_asset_id ON alerts(asset_id);"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS idx_work_orders_asset_id ON work_orders(asset_id);"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "CREATE INDEX IF NOT EXISTS idx_work_orders_alert_id ON work_orders(alert_id);"

# updated_at triggers for assets + work_orders (idempotent)
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS \$\$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
DO \$\$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_assets_updated_at'
  ) THEN
    CREATE TRIGGER trg_assets_updated_at
    BEFORE UPDATE ON assets
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
  END IF;
END
\$\$;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
DO \$\$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_work_orders_updated_at'
  ) THEN
    CREATE TRIGGER trg_work_orders_updated_at
    BEFORE UPDATE ON work_orders
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
  END IF;
END
\$\$;"

# -----------------------------
# Seed assets (5–10)
# -----------------------------
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO assets(asset_tag, name, asset_type, location, health_score, status)
VALUES ('TX-1001','Transformer A','transformer','Substation 1',82,'active')
ON CONFLICT (asset_tag) DO UPDATE
SET name=EXCLUDED.name, asset_type=EXCLUDED.asset_type, location=EXCLUDED.location, health_score=EXCLUDED.health_score, status=EXCLUDED.status;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO assets(asset_tag, name, asset_type, location, health_score, status)
VALUES ('TX-1002','Transformer B','transformer','Substation 2',55,'active')
ON CONFLICT (asset_tag) DO UPDATE
SET name=EXCLUDED.name, asset_type=EXCLUDED.asset_type, location=EXCLUDED.location, health_score=EXCLUDED.health_score, status=EXCLUDED.status;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO assets(asset_tag, name, asset_type, location, health_score, status)
VALUES ('PM-2001','Pump Station 1','pump','Pump Site Alpha',35,'active')
ON CONFLICT (asset_tag) DO UPDATE
SET name=EXCLUDED.name, asset_type=EXCLUDED.asset_type, location=EXCLUDED.location, health_score=EXCLUDED.health_score, status=EXCLUDED.status;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO assets(asset_tag, name, asset_type, location, health_score, status)
VALUES ('PM-2002','Pump Station 2','pump','Pump Site Beta',25,'active')
ON CONFLICT (asset_tag) DO UPDATE
SET name=EXCLUDED.name, asset_type=EXCLUDED.asset_type, location=EXCLUDED.location, health_score=EXCLUDED.health_score, status=EXCLUDED.status;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO assets(asset_tag, name, asset_type, location, health_score, status)
VALUES ('PL-3001','Pipeline Segment 12','pipeline','District 4',68,'active')
ON CONFLICT (asset_tag) DO UPDATE
SET name=EXCLUDED.name, asset_type=EXCLUDED.asset_type, location=EXCLUDED.location, health_score=EXCLUDED.health_score, status=EXCLUDED.status;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO assets(asset_tag, name, asset_type, location, health_score, status)
VALUES ('SS-4001','Substation Delta','substation','Grid Zone 7',90,'active')
ON CONFLICT (asset_tag) DO UPDATE
SET name=EXCLUDED.name, asset_type=EXCLUDED.asset_type, location=EXCLUDED.location, health_score=EXCLUDED.health_score, status=EXCLUDED.status;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO assets(asset_tag, name, asset_type, location, health_score, status)
VALUES ('SS-4002','Substation Echo','substation','Grid Zone 3',42,'active')
ON CONFLICT (asset_tag) DO UPDATE
SET name=EXCLUDED.name, asset_type=EXCLUDED.asset_type, location=EXCLUDED.location, health_score=EXCLUDED.health_score, status=EXCLUDED.status;"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO assets(asset_tag, name, asset_type, location, health_score, status)
VALUES ('TX-1003','Transformer C','transformer','Substation 3',15,'active')
ON CONFLICT (asset_tag) DO UPDATE
SET name=EXCLUDED.name, asset_type=EXCLUDED.asset_type, location=EXCLUDED.location, health_score=EXCLUDED.health_score, status=EXCLUDED.status;"

# -----------------------------
# Seed inspections: at least one per asset (idempotent via unique key)
# We'll prevent duplicates by checking for (asset_id, inspector_name, inspection_date::date)
# -----------------------------
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH a AS (
  SELECT id, asset_tag, health_score FROM assets WHERE asset_tag = 'TX-1001'
)
INSERT INTO inspections(asset_id, inspector_name, inspection_date, notes, observed_health_score)
SELECT a.id, 'Alex Inspector', NOW() - INTERVAL '10 days', 'Oil level normal. No hotspots observed.', a.health_score
FROM a
WHERE NOT EXISTS (
  SELECT 1 FROM inspections i
  WHERE i.asset_id = a.id AND i.inspector_name='Alex Inspector' AND i.inspection_date::date = (NOW() - INTERVAL '10 days')::date
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH a AS (
  SELECT id, asset_tag, health_score FROM assets WHERE asset_tag = 'TX-1002'
)
INSERT INTO inspections(asset_id, inspector_name, inspection_date, notes, observed_health_score)
SELECT a.id, 'Morgan Inspector', NOW() - INTERVAL '8 days', 'Minor corrosion on casing. Recommend monitoring.', a.health_score
FROM a
WHERE NOT EXISTS (
  SELECT 1 FROM inspections i
  WHERE i.asset_id = a.id AND i.inspector_name='Morgan Inspector' AND i.inspection_date::date = (NOW() - INTERVAL '8 days')::date
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH a AS (
  SELECT id, asset_tag, health_score FROM assets WHERE asset_tag = 'PM-2001'
)
INSERT INTO inspections(asset_id, inspector_name, inspection_date, notes, observed_health_score)
SELECT a.id, 'Jamie Inspector', NOW() - INTERVAL '6 days', 'Vibration high. Bearing wear suspected.', a.health_score
FROM a
WHERE NOT EXISTS (
  SELECT 1 FROM inspections i
  WHERE i.asset_id = a.id AND i.inspector_name='Jamie Inspector' AND i.inspection_date::date = (NOW() - INTERVAL '6 days')::date
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH a AS (
  SELECT id, asset_tag, health_score FROM assets WHERE asset_tag = 'PM-2002'
)
INSERT INTO inspections(asset_id, inspector_name, inspection_date, notes, observed_health_score)
SELECT a.id, 'Jamie Inspector', NOW() - INTERVAL '5 days', 'Seal leak observed. Urgent maintenance required.', a.health_score
FROM a
WHERE NOT EXISTS (
  SELECT 1 FROM inspections i
  WHERE i.asset_id = a.id AND i.inspector_name='Jamie Inspector' AND i.inspection_date::date = (NOW() - INTERVAL '5 days')::date
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH a AS (
  SELECT id, asset_tag, health_score FROM assets WHERE asset_tag = 'PL-3001'
)
INSERT INTO inspections(asset_id, inspector_name, inspection_date, notes, observed_health_score)
SELECT a.id, 'Alex Inspector', NOW() - INTERVAL '7 days', 'Pressure stable; minor valve noise.', a.health_score
FROM a
WHERE NOT EXISTS (
  SELECT 1 FROM inspections i
  WHERE i.asset_id = a.id AND i.inspector_name='Alex Inspector' AND i.inspection_date::date = (NOW() - INTERVAL '7 days')::date
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH a AS (
  SELECT id, asset_tag, health_score FROM assets WHERE asset_tag = 'SS-4001'
)
INSERT INTO inspections(asset_id, inspector_name, inspection_date, notes, observed_health_score)
SELECT a.id, 'Morgan Inspector', NOW() - INTERVAL '9 days', 'Breaker tests passed.', a.health_score
FROM a
WHERE NOT EXISTS (
  SELECT 1 FROM inspections i
  WHERE i.asset_id = a.id AND i.inspector_name='Morgan Inspector' AND i.inspection_date::date = (NOW() - INTERVAL '9 days')::date
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH a AS (
  SELECT id, asset_tag, health_score FROM assets WHERE asset_tag = 'SS-4002'
)
INSERT INTO inspections(asset_id, inspector_name, inspection_date, notes, observed_health_score)
SELECT a.id, 'Alex Inspector', NOW() - INTERVAL '4 days', 'Thermal scan shows mild overheating. Schedule follow-up.', a.health_score
FROM a
WHERE NOT EXISTS (
  SELECT 1 FROM inspections i
  WHERE i.asset_id = a.id AND i.inspector_name='Alex Inspector' AND i.inspection_date::date = (NOW() - INTERVAL '4 days')::date
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH a AS (
  SELECT id, asset_tag, health_score FROM assets WHERE asset_tag = 'TX-1003'
)
INSERT INTO inspections(asset_id, inspector_name, inspection_date, notes, observed_health_score)
SELECT a.id, 'Jamie Inspector', NOW() - INTERVAL '3 days', 'Severe overheating and insulation degradation. Immediate action recommended.', a.health_score
FROM a
WHERE NOT EXISTS (
  SELECT 1 FROM inspections i
  WHERE i.asset_id = a.id AND i.inspector_name='Jamie Inspector' AND i.inspection_date::date = (NOW() - INTERVAL '3 days')::date
);"

# -----------------------------
# Auto-generated alerts for health < 40 (idempotent)
# -----------------------------
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
INSERT INTO alerts(asset_id, severity, alert_type, message, health_score_at_alert, is_acknowledged)
SELECT
  a.id,
  CASE
    WHEN a.health_score < 20 THEN 'critical'
    WHEN a.health_score < 30 THEN 'high'
    ELSE 'medium'
  END AS severity,
  'low_health' AS alert_type,
  'Asset health score below threshold (<40). Review and take action.' AS message,
  a.health_score,
  FALSE
FROM assets a
WHERE a.health_score < 40
AND NOT EXISTS (
  SELECT 1 FROM alerts al
  WHERE al.asset_id = a.id AND al.alert_type='low_health'
);"

# -----------------------------
# 1–2 work orders linked to alerts (idempotent)
# -----------------------------
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH target AS (
  SELECT a.id AS asset_id, al.id AS alert_id
  FROM assets a
  JOIN alerts al ON al.asset_id = a.id
  WHERE a.asset_tag = 'PM-2002' AND al.alert_type='low_health'
  LIMIT 1
)
INSERT INTO work_orders(asset_id, alert_id, title, description, priority, status, due_date)
SELECT
  target.asset_id,
  target.alert_id,
  'Replace pump seal and inspect bearings',
  'Leak observed during inspection; replace seal and inspect bearings. Verify vibration after repair.',
  'P1',
  'open',
  NOW() + INTERVAL '7 days'
FROM target
WHERE NOT EXISTS (
  SELECT 1 FROM work_orders wo
  WHERE wo.alert_id = target.alert_id AND wo.title = 'Replace pump seal and inspect bearings'
);"

psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "
WITH target AS (
  SELECT a.id AS asset_id, al.id AS alert_id
  FROM assets a
  JOIN alerts al ON al.asset_id = a.id
  WHERE a.asset_tag = 'TX-1003' AND al.alert_type='low_health'
  LIMIT 1
)
INSERT INTO work_orders(asset_id, alert_id, title, description, priority, status, due_date)
SELECT
  target.asset_id,
  target.alert_id,
  'Transformer urgent thermal mitigation',
  'Severe overheating risk. Perform thermal mitigation and plan insulation test.',
  'P1',
  'open',
  NOW() + INTERVAL '3 days'
FROM target
WHERE NOT EXISTS (
  SELECT 1 FROM work_orders wo
  WHERE wo.alert_id = target.alert_id AND wo.title = 'Transformer urgent thermal mitigation'
);"

echo "Seed complete."
echo "Tables: assets, inspections, alerts, work_orders"
echo "Counts:"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "SELECT 'assets' AS table, COUNT(*) FROM assets;"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "SELECT 'inspections' AS table, COUNT(*) FROM inspections;"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "SELECT 'alerts' AS table, COUNT(*) FROM alerts;"
psql "${DB_URL}" -v ON_ERROR_STOP=1 -c "SELECT 'work_orders' AS table, COUNT(*) FROM work_orders;"
