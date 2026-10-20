-- Existing accounts keep their data; legacy accounts without a password hash must set one
-- through a separately controlled credential recovery process before they can sign in.
ALTER TABLE app_user ADD COLUMN password_hash VARCHAR(100);

-- The expression index preserves existing email values while enforcing the same canonical
-- representation used by registration. If historical emails collide after normalization,
-- Flyway stops here so the records can be resolved explicitly without data loss.
CREATE UNIQUE INDEX app_user_email_normalized_uidx ON app_user (lower(btrim(email)));

CREATE TABLE refresh_session (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    token_hash CHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    replaced_by_session_id UUID REFERENCES refresh_session(id),
    CONSTRAINT refresh_session_token_hash_format_check CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT refresh_session_expiry_check CHECK (expires_at > created_at)
);
CREATE INDEX refresh_session_user_id_idx ON refresh_session (user_id);
