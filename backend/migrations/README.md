# Database Migrations

This directory contains SQL migration scripts for the download queue system.

## Migration Files

### 001_create_queue_table.sql
Creates the `download_queue` table with all necessary indexes and constraints.

**What it creates**:
- `download_queue` table with complete schema
- Indexes for performance (status, priority, url, idempotency_key, created_at)
- Trigger for automatic `updated_at` timestamp
- CHECK constraints for data validation

**Run this**:
```bash
sqlite3 /tmp/music_downloader/database/queue.db < migrations/001_create_queue_table.sql
```

### 001_rollback.sql
Rollback script to drop the `download_queue` table.

**WARNING**: This will delete all queue data!

**Run this**:
```bash
sqlite3 /tmp/music_downloader/database/queue.db < migrations/001_rollback.sql
```

## Automatic Migrations

The application automatically creates tables on startup via SQLAlchemy:
```python
from app.core.database import init_database
init_database()
```

These SQL files are provided for:
1. **Manual migrations** in production
2. **Testing** migration logic
3. **Documentation** of schema changes
4. **Rollback** capabilities

## Migration Best Practices

### Before Running Migration

1. **Backup the database**:
```bash
cp /tmp/music_downloader/database/queue.db /tmp/music_downloader/database/queue_backup_$(date +%Y%m%d_%H%M%S).db
```

2. **Test on copy first**:
```bash
cp /tmp/music_downloader/database/queue.db /tmp/test_queue.db
sqlite3 /tmp/test_queue.db < migrations/001_create_queue_table.sql
```

3. **Verify schema**:
```bash
sqlite3 /tmp/test_queue.db ".schema download_queue"
```

### Running Migration

```bash
# Run migration
sqlite3 /tmp/music_downloader/database/queue.db < migrations/001_create_queue_table.sql

# Verify
sqlite3 /tmp/music_downloader/database/queue.db "SELECT COUNT(*) FROM download_queue;"
```

### Rolling Back

```bash
# Rollback
sqlite3 /tmp/music_downloader/database/queue.db < migrations/001_rollback.sql

# Restore from backup if needed
cp /tmp/music_downloader/database/queue_backup_20251115_103000.db /tmp/music_downloader/database/queue.db
```

## Future Migrations

When adding new migrations:

1. Create forward migration: `00X_description.sql`
2. Create rollback migration: `00X_rollback.sql`
3. Test both forward and rollback
4. Update this README
5. Document in QUEUE_IMPLEMENTATION_REPORT.md

## Schema Verification

```bash
# Connect to database
sqlite3 /tmp/music_downloader/database/queue.db

# View schema
.schema download_queue

# View indexes
.indexes download_queue

# View triggers
SELECT name, sql FROM sqlite_master WHERE type='trigger';

# Exit
.quit
```

## Troubleshooting

### Migration Already Applied
If you see "table already exists", the migration was already run. This is safe to ignore.

### Rollback Fails
If rollback fails, manually drop the table:
```sql
DROP TABLE IF EXISTS download_queue;
```

### Corrupt Database
If database is corrupt, delete and recreate:
```bash
rm /tmp/music_downloader/database/queue.db
python -c "from app.core.database import init_database; init_database()"
```
