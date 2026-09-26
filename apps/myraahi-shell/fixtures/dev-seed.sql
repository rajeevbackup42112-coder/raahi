-- DEVELOPMENT / STAGING FIXTURE ONLY.
-- Do not treat these rows as production launch truth.

PRAGMA foreign_keys = ON;

INSERT OR REPLACE INTO locations
(id, slug, display_name, region, state_or_province, country_code, state, display_order, created_at, updated_at)
VALUES
('loc-gomoh', 'gomoh', 'Gomoh', 'Dhanbad district', 'Jharkhand', 'IN', 'LIVE', 10, datetime('now'), datetime('now')),
('loc-dhanbad', 'dhanbad', 'Dhanbad', 'Dhanbad district', 'Jharkhand', 'IN', 'LIVE', 20, datetime('now'), datetime('now'));

INSERT OR REPLACE INTO products
(id, product_key, display_name, short_description, icon_ref, entry_url, state, display_order, created_at, updated_at)
VALUES
('prd-learning', 'learning', 'Learning', 'Find teachers and learning opportunities near you.', 'learning', 'https://learning.myraahi.co.in/', 'ACTIVE', 10, datetime('now'), datetime('now')),
('prd-toto', 'toto', 'ToTo', 'Find local transport options for your journey.', 'toto', 'https://myraahi.co.in/', 'ACTIVE', 20, datetime('now'), datetime('now'));

INSERT OR REPLACE INTO location_products
(id, location_id, product_id, state, availability_message, display_order, created_at, updated_at)
VALUES
('lp-gomoh-learning', 'loc-gomoh', 'prd-learning', 'LIVE', NULL, 10, datetime('now'), datetime('now')),
('lp-gomoh-toto', 'loc-gomoh', 'prd-toto', 'LIVE', NULL, 20, datetime('now'), datetime('now')),
('lp-dhanbad-learning', 'loc-dhanbad', 'prd-learning', 'LIVE', NULL, 10, datetime('now'), datetime('now')),
('lp-dhanbad-toto', 'loc-dhanbad', 'prd-toto', 'PAUSED', 'Pilot configuration: temporarily unavailable.', 20, datetime('now'), datetime('now'));
