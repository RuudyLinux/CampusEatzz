-- Single-device session enforcement
-- Run this once against your MySQL database before deploying the updated API.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS active_session_jti VARCHAR(36) NULL DEFAULT NULL
        COMMENT 'JWT jti claim of the currently active session. NULL = no active session.';

-- Optional index for fast lookup during per-request validation.
-- The column is only ever queried by primary key (WHERE id = ?), so this index
-- is a safety net for legacy schemas that use a different PK name.
-- Skip if your users table is already keyed on id with a clustered index.
-- CREATE INDEX idx_users_active_session_jti ON users (active_session_jti);
