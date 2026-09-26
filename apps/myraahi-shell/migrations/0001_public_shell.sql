PRAGMA foreign_keys = ON;

CREATE TABLE locations (
  id TEXT PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  region TEXT,
  state_or_province TEXT,
  country_code TEXT NOT NULL DEFAULT 'IN',
  state TEXT NOT NULL
    CHECK (state IN ('PREPARING','LIVE','PAUSED','RETIRED')),
  display_order INTEGER NOT NULL DEFAULT 100,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_locations_public_order
ON locations(state, display_order, display_name);

CREATE TABLE products (
  id TEXT PRIMARY KEY,
  product_key TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  short_description TEXT NOT NULL,
  icon_ref TEXT NOT NULL,
  entry_url TEXT NOT NULL,
  state TEXT NOT NULL
    CHECK (state IN ('ACTIVE','RETIRED')),
  display_order INTEGER NOT NULL DEFAULT 100,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE location_products (
  id TEXT PRIMARY KEY,
  location_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  state TEXT NOT NULL
    CHECK (state IN ('OFF','PREPARING','LIVE','PAUSED')),
  local_display_name TEXT,
  local_short_description TEXT,
  availability_message TEXT,
  display_order INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (location_id) REFERENCES locations(id),
  FOREIGN KEY (product_id) REFERENCES products(id),
  UNIQUE (location_id, product_id)
);

CREATE INDEX idx_location_products_catalog
ON location_products(location_id, state, display_order);

CREATE INDEX idx_location_products_product
ON location_products(product_id);

CREATE TABLE config_audit_events (
  id TEXT PRIMARY KEY,
  actor_type TEXT NOT NULL,
  actor_ref TEXT,
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  location_id TEXT,
  product_id TEXT,
  reason TEXT,
  before_json TEXT,
  after_json TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE schema_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

INSERT INTO schema_meta(key, value, updated_at)
VALUES ('schema_version', '0.1', datetime('now'));
