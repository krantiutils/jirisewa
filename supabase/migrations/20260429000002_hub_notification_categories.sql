-- Phase 1 — Aggregation Hubs: extend notification_category enum.
-- Split into its own migration because Postgres won't let a transaction
-- reference enum values it added in the same transaction.

ALTER TYPE notification_category ADD VALUE IF NOT EXISTS 'hub_dropoff_received';
ALTER TYPE notification_category ADD VALUE IF NOT EXISTS 'hub_dropoff_dispatched';
ALTER TYPE notification_category ADD VALUE IF NOT EXISTS 'hub_dropoff_expiring';
ALTER TYPE notification_category ADD VALUE IF NOT EXISTS 'hub_dropoff_expired';
