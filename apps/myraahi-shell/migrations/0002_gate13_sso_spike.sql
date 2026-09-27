-- Gate 13D technology spike only.
-- These tables are not part of the frozen production shared-account schema yet.

CREATE TABLE sso_spike_accounts (
  id TEXT PRIMARY KEY,
  issuer TEXT NOT NULL,
  subject TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE (issuer, subject)
);

CREATE TABLE sso_spike_sessions (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  FOREIGN KEY (account_id) REFERENCES sso_spike_accounts(id)
);

CREATE INDEX idx_sso_spike_sessions_account
ON sso_spike_sessions(account_id);

CREATE INDEX idx_sso_spike_sessions_expiry
ON sso_spike_sessions(expires_at);
