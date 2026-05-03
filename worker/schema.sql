CREATE TABLE IF NOT EXISTS license_codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code_hash TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'active',
  tier TEXT NOT NULL DEFAULT 'premium',
  expires_at TEXT,
  max_devices INTEGER NOT NULL DEFAULT 1,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS license_bindings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  license_code_id INTEGER NOT NULL,
  install_id_hash TEXT NOT NULL,
  device_name TEXT,
  bound_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  revoked_at TEXT,
  FOREIGN KEY (license_code_id) REFERENCES license_codes(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_license_bindings_unique
ON license_bindings(license_code_id, install_id_hash);

CREATE TABLE IF NOT EXISTS license_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  license_code_id INTEGER,
  event_type TEXT NOT NULL,
  payload_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (license_code_id) REFERENCES license_codes(id)
);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_no TEXT NOT NULL UNIQUE,
  access_token_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  product_name TEXT NOT NULL,
  tier TEXT NOT NULL DEFAULT 'premium',
  max_devices INTEGER NOT NULL DEFAULT 1,
  expires_at TEXT,
  buyer_contact TEXT,
  note TEXT,
  payment_provider TEXT,
  amount_cents INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  external_payment_id TEXT,
  issued_license_code_id INTEGER,
  issued_code_plaintext TEXT,
  created_at TEXT NOT NULL,
  paid_at TEXT,
  fulfilled_at TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (issued_license_code_id) REFERENCES license_codes(id)
);

CREATE INDEX IF NOT EXISTS idx_orders_status_created
ON orders(status, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_external_payment
ON orders(external_payment_id)
WHERE external_payment_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS order_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  payload_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id)
);

CREATE TABLE IF NOT EXISTS safety_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category TEXT NOT NULL,
  safety_code TEXT NOT NULL,
  prompt_excerpt TEXT,
  has_reference_image INTEGER NOT NULL DEFAULT 0,
  license_code_id INTEGER,
  install_id_hash TEXT,
  payload_json TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (license_code_id) REFERENCES license_codes(id)
);

CREATE INDEX IF NOT EXISTS idx_safety_events_created
ON safety_events(created_at DESC);
