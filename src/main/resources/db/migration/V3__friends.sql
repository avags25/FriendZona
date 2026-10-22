ALTER TABLE app_user ADD COLUMN friend_code VARCHAR(13);

DO $$
DECLARE
    account RECORD;
    generated_code VARCHAR(13);
BEGIN
    FOR account IN SELECT id FROM app_user ORDER BY id LOOP
        LOOP
            generated_code := 'SW-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
            EXIT WHEN NOT EXISTS (SELECT 1 FROM app_user WHERE friend_code = generated_code);
        END LOOP;
        UPDATE app_user SET friend_code = generated_code WHERE id = account.id;
    END LOOP;
END $$;

ALTER TABLE app_user ALTER COLUMN friend_code SET NOT NULL;
ALTER TABLE app_user
    ADD CONSTRAINT app_user_friend_code_key UNIQUE (friend_code),
    ADD CONSTRAINT app_user_friend_code_format_check CHECK (friend_code ~ '^SW-[A-Z0-9]{10}$');

CREATE TABLE friendship_request (
    id UUID PRIMARY KEY,
    user_low_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    user_high_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    status VARCHAR(10) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT friendship_request_pair_order_check CHECK (user_low_id < user_high_id),
    CONSTRAINT friendship_request_distinct_users_check CHECK (requester_id <> recipient_id),
    CONSTRAINT friendship_request_pair_members_check CHECK (
        (requester_id = user_low_id AND recipient_id = user_high_id)
        OR (requester_id = user_high_id AND recipient_id = user_low_id)
    ),
    CONSTRAINT friendship_request_status_check CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED')),
    CONSTRAINT friendship_request_pair_key UNIQUE (user_low_id, user_high_id)
);

CREATE INDEX friendship_request_incoming_idx
    ON friendship_request (recipient_id, created_at DESC) WHERE status = 'PENDING';
CREATE INDEX friendship_request_outgoing_idx
    ON friendship_request (requester_id, created_at DESC) WHERE status = 'PENDING';
CREATE INDEX friendship_accepted_pair_low_idx
    ON friendship_request (user_low_id, created_at DESC) WHERE status = 'ACCEPTED';
CREATE INDEX friendship_accepted_pair_high_idx
    ON friendship_request (user_high_id, created_at DESC) WHERE status = 'ACCEPTED';
