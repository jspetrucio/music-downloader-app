-- Rollback Migration: Drop download_queue table
-- Version: 001
-- Date: 2025-11-15
-- Description: Rollback initial queue system implementation

-- WARNING: This will delete all queue data!

-- Drop trigger
DROP TRIGGER IF EXISTS update_queue_timestamp;

-- Drop indexes
DROP INDEX IF EXISTS idx_queue_created_at;
DROP INDEX IF EXISTS idx_queue_idempotency;
DROP INDEX IF EXISTS idx_queue_url;
DROP INDEX IF EXISTS idx_queue_priority;
DROP INDEX IF EXISTS idx_queue_status;

-- Drop table
DROP TABLE IF EXISTS download_queue;

-- Rollback completed
