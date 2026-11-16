CREATE SCHEMA IF NOT EXISTS youtube;
SET search_path TO youtube;


CREATE TABLE users (
    user_id         INTEGER         PRIMARY KEY,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    display_name    VARCHAR(100)    NOT NULL,
    country_code    CHAR(2)         NOT NULL
        CHECK (country_code ~ '^[A-Z]{2}$'),
    birth_year      SMALLINT
        CHECK (birth_year BETWEEN 1900 AND 2026),
    premium_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL
);



CREATE TABLE channels (
    channel_id          INTEGER         PRIMARY KEY,
    owner_user_id       INTEGER         NOT NULL,
    handle              VARCHAR(30)     NOT NULL UNIQUE,
    channel_name        VARCHAR(100)    NOT NULL,
    country_code        CHAR(2)         NOT NULL
        CHECK (country_code ~ '^[A-Z]{2}$'),
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    monetization_status VARCHAR(20) NOT NULL
        DEFAULT 'NOT_ELIGIBLE'
        CHECK (
                monetization_status IN (
                'NOT_ELIGIBLE',
                'ELIGIBLE',
                'SUSPENDED'
            )
        ),
    subscriber_count INTEGER NOT NULL DEFAULT 0
        CHECK (subscriber_count >= 0),
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_channels_owner
        FOREIGN KEY (owner_user_id)
        REFERENCES users(user_id)
        ON DELETE RESTRICT
);



CREATE TABLE videos (
    video_id        VARCHAR(11)     PRIMARY KEY         CHECK (video_id ~ '^[A-Za-z0-9_-]{11}$'),
    channel_id      INTEGER         NOT NULL,
    title           VARCHAR(100)    NOT NULL,
    description     TEXT,

    category VARCHAR(20) NOT NULL
        CHECK (category IN (
            'Comedy',
            'Cooking',
            'Education',
            'Film',
            'Gaming',
            'Music',
            'News',
            'Sports',
            'Tech',
            'Vlogs'
        )),

    duration_sec        INTEGER         NOT NULL        CHECK (duration_sec > 0),
    is_short            BOOLEAN         NOT NULL,
    is_made_for_kids    BOOLEAN         NOT NULL DEFAULT FALSE,

    visibility          VARCHAR(10)     NOT NULL
        CHECK (visibility IN (
            'PRIVATE',
            'PUBLIC',
            'SCHEDULED',
            'UNLISTED'
        )),

    uploaded_at         TIMESTAMPTZ     NOT NULL,
    published_at        TIMESTAMPTZ,

    view_count          BIGINT          NOT NULL DEFAULT 0      CHECK (view_count >= 0),

    CONSTRAINT fk_videos_channel
        FOREIGN KEY (channel_id)
        REFERENCES channels(channel_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_video_short_duration
        CHECK (NOT is_short OR duration_sec <= 60),

    CONSTRAINT chk_private_video_unpublished
        CHECK (visibility <> 'PRIVATE' OR published_at IS NULL)
);


CREATE TABLE subscriptions (
    user_id         INTEGER         NOT NULL,
    channel_id      INTEGER         NOT NULL,

    notifications   VARCHAR(15)     NOT NULL    
    CHECK (notifications IN (
        'ALL',
        'NONE',
        'PERSONALIZED'
    )),

    subscribed_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT pk_subscriptions
        PRIMARY KEY (user_id, channel_id),

    CONSTRAINT fk_subscriptions_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_subscriptions_channel
        FOREIGN KEY (channel_id)
        REFERENCES channels(channel_id)
        ON DELETE CASCADE
);


CREATE TABLE watch_events (
    watch_id        BIGINT          PRIMARY KEY,
    user_id         INTEGER,
    video_id        VARCHAR(11)     NOT NULL,
    started_at      TIMESTAMPTZ     NOT NULL,
    watch_seconds   INTEGER         NOT NULL        CHECK (watch_seconds >= 0),
    device          VARCHAR(10)     NOT NULL        CHECK (device IN (
            'ANDROID',
            'IOS',
            'TV',
            'WEB'
        )),

    traffic_source VARCHAR(20) NOT NULL
        CHECK (traffic_source IN (
            'EXTERNAL',
            'HOME',
            'SEARCH',
            'SHORTS_FEED',
            'SUBSCRIPTION',
            'SUGGESTED'
        )),

    CONSTRAINT fk_watch_events_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_watch_events_video
        FOREIGN KEY (video_id)
        REFERENCES videos(video_id)
        ON DELETE RESTRICT
);


CREATE TABLE video_reactions (
    user_id         INTEGER         NOT NULL,
    video_id        VARCHAR(11)     NOT NULL,
    reaction        VARCHAR(10)     NOT NULL        CHECK (reaction IN ('LIKE', 'DISLIKE')),
    reacted_at      TIMESTAMPTZ     NOT NULL,

    CONSTRAINT pk_video_reactions
        PRIMARY KEY (user_id, video_id),

    CONSTRAINT fk_video_reactions_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_video_reactions_video
        FOREIGN KEY (video_id)
        REFERENCES videos(video_id)
        ON DELETE CASCADE
);


CREATE TABLE comments (
    comment_id          BIGINT          PRIMARY KEY,
    video_id            VARCHAR(11)     NOT NULL,
    user_id             INTEGER         NOT NULL,
    parent_comment_id   BIGINT,
    body                TEXT            NOT NULL,
    like_count          INTEGER         NOT NULL DEFAULT 0      CHECK (like_count >= 0),
    is_pinned           BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL,

    CONSTRAINT fk_comments_video
        FOREIGN KEY (video_id)
        REFERENCES videos(video_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_comments_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_comments_parent
        FOREIGN KEY (parent_comment_id)
        REFERENCES comments(comment_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_comments_not_self_parent
        CHECK (parent_comment_id IS NULL
               OR parent_comment_id <> comment_id),

    CONSTRAINT chk_replies_not_pinned
        CHECK (parent_comment_id IS NULL OR is_pinned = FALSE)
);


CREATE TABLE playlists (
    playlist_id         INTEGER         PRIMARY KEY,
    owner_user_id       INTEGER         NOT NULL,
    title               VARCHAR(150)    NOT NULL,
    visibility          VARCHAR(10)     NOT NULL        CHECK (visibility IN ('PUBLIC', 'UNLISTED', 'PRIVATE')),
    created_at          TIMESTAMPTZ     NOT NULL,

    CONSTRAINT fk_playlists_owner
        FOREIGN KEY (owner_user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE
);


CREATE TABLE playlist_items (
    playlist_id         INTEGER         NOT NULL,
    position            SMALLINT        NOT NULL        CHECK (position > 0),
    video_id            VARCHAR(11)     NOT NULL,
    added_at            TIMESTAMPTZ     NOT NULL,

    CONSTRAINT pk_playlist_items
        PRIMARY KEY (playlist_id, position),

    CONSTRAINT uq_playlist_items_video
        UNIQUE (playlist_id, video_id),

    CONSTRAINT fk_playlist_items_playlist
        FOREIGN KEY (playlist_id)
        REFERENCES playlists(playlist_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_playlist_items_video
        FOREIGN KEY (video_id)
        REFERENCES videos(video_id)
        ON DELETE CASCADE
);


CREATE TABLE ad_impressions (
    impression_id   BIGINT          PRIMARY KEY,
    watch_id        BIGINT          NOT NULL,
    ad_format       VARCHAR(10)     NOT NULL        CHECK (ad_format IN ('MIDROLL', 'PREROLL')),
    revenue_inr     NUMERIC(10,4)   NOT NULL        CHECK (revenue_inr >= 0),
    shown_at        TIMESTAMPTZ     NOT NULL,

    CONSTRAINT fk_ad_impressions_watch
        FOREIGN KEY (watch_id)
        REFERENCES watch_events(watch_id)
        ON DELETE RESTRICT
);



