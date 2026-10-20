CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE app_user (
    id UUID PRIMARY KEY,
    email VARCHAR(320) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE meeting (
    id UUID PRIMARY KEY,
    organizer_id UUID NOT NULL REFERENCES app_user(id),
    title VARCHAR(120) NOT NULL,
    description TEXT,
    place_provider VARCHAR(40) NOT NULL,
    provider_place_id VARCHAR(200),
    place_name VARCHAR(200) NOT NULL,
    place_address TEXT,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    time_zone VARCHAR(64) NOT NULL,
    status VARCHAR(16) NOT NULL CHECK (status IN ('SCHEDULED', 'CANCELLED', 'COMPLETED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX meeting_location_gix ON meeting USING GIST (location);
CREATE INDEX meeting_starts_at_idx ON meeting (starts_at);

CREATE TABLE meeting_participant (
    meeting_id UUID NOT NULL REFERENCES meeting(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES app_user(id),
    response VARCHAR(16) NOT NULL CHECK (response IN ('INVITED', 'GOING', 'MAYBE', 'DECLINED', 'ON_THE_WAY', 'ARRIVED', 'LATE')),
    responded_at TIMESTAMPTZ,
    PRIMARY KEY (meeting_id, user_id)
);
