-- Migration: Create download_queue table
-- Version: 001
-- Date: 2025-11-15
-- Description: Initial queue system implementation

-- Create download_queue table
CREATE TABLE IF NOT EXISTS download_queue (
    -- Primary key
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Request information
    url TEXT NOT NULL,
    format TEXT NOT NULL CHECK(format IN ('mp3', 'm4a')),
    priority TEXT NOT NULL DEFAULT 'normal' CHECK(priority IN ('high', 'normal', 'low')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'downloading', 'completed', 'failed', 'paused', 'cancelled')),
    
    -- Metadata (enriched asynchronously)
    title TEXT,
    artist TEXT,
    duration INTEGER,
    thumbnail TEXT,
    
    -- Progress tracking
    progress INTEGER DEFAULT 0 CHECK(progress >= 0 AND progress <= 100),
    current_retry INTEGER DEFAULT 0 CHECK(current_retry >= 0),
    max_retries INTEGER DEFAULT 3 CHECK(max_retries >= 0),
    
    -- Error tracking
    error_message TEXT,
    error_code TEXT,
    
    -- File information
    file_path TEXT,
    file_size INTEGER,
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Idempotency (prevents duplicate queue items)
    idempotency_key TEXT UNIQUE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_queue_status ON download_queue(status);
CREATE INDEX IF NOT EXISTS idx_queue_priority ON download_queue(priority);
CREATE INDEX IF NOT EXISTS idx_queue_url ON download_queue(url);
CREATE INDEX IF NOT EXISTS idx_queue_idempotency ON download_queue(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_queue_created_at ON download_queue(created_at);

-- Create trigger to update updated_at timestamp
CREATE TRIGGER IF NOT EXISTS update_queue_timestamp 
AFTER UPDATE ON download_queue
BEGIN
    UPDATE download_queue SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Migration completed successfully
