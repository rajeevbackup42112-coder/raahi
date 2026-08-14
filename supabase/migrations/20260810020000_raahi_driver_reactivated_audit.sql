-- ============================================================
-- RAAHI — Add driver_reactivated audit_action enum value
-- Migration: 20260810020000_raahi_driver_reactivated_audit.sql
-- ============================================================
--
-- PURPOSE:
--   Adds a distinct audit_action enum value for driver reactivation
--   (recovery from suspension), separate from first-time driver_approved.
--
--   driver_approved  = first-time verification of a pending driver
--   driver_suspended = admin suspends an approved driver
--   driver_reactivated = admin restores a suspended driver to approved/offline
--
-- This is a forward-only migration. No historical migrations are modified.
-- ============================================================

-- Add the new enum value safely (idempotent via IF NOT EXISTS)
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'driver_reactivated';

-- Commit so the new value is visible to subsequent statements in this session
COMMIT;
