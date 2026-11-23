-- Phase 5: Demonstration of monthly RANGE partitioning for watch_events.
--
-- IMPORTANT:
-- This creates a separate demonstration table named
-- youtube.watch_events_partitioned. It does NOT replace, truncate, or modify
-- the benchmark table youtube.watch_events.
--
-- The observed large-data range is:
--   2025-01-01 00:00:00+05:30 through 2026-06-30 23:59:48+05:30
-- Monthly partitions are created for Jan 2025 through Jun 2026.
-- A DEFAULT partition catches rows outside that range.
--
-- PostgreSQL partitioned-table rule:
-- A PRIMARY KEY or UNIQUE constraint on a partitioned table must include
-- every partition key column. Since the partition key is started_at, the
-- primary key below is (watch_id, started_at), not watch_id alone.
--
-- Consequence:
-- (watch_id, started_at) guarantees uniqueness of the pair, but does not
-- enforce global uniqueness of watch_id by itself. If other tables need to
-- reference a watch event, they must carry both columns and use a composite
-- foreign key, or a separate non-partitioned watch_id registry must be used.
-- In particular, ad_impressions currently references watch_events(watch_id);
-- that FK would need redesign before migrating the production table.

CREATE SCHEMA IF NOT EXISTS youtube;

-- Safe to rerun: only the demonstration table is dropped.
DROP TABLE IF EXISTS youtube.watch_events_partitioned CASCADE;

CREATE TABLE youtube.watch_events_partitioned (
    watch_id        BIGINT          NOT NULL,
    user_id         INTEGER,
    video_id        VARCHAR(11)     NOT NULL,
    started_at      TIMESTAMPTZ     NOT NULL,
    watch_seconds   INTEGER         NOT NULL CHECK (watch_seconds >= 0),
    device          VARCHAR(10)     NOT NULL
        CHECK (device IN ('ANDROID', 'IOS', 'TV', 'WEB')),
    traffic_source  VARCHAR(20)     NOT NULL
        CHECK (traffic_source IN (
            'EXTERNAL',
            'HOME',
            'SEARCH',
            'SHORTS_FEED',
            'SUBSCRIPTION',
            'SUGGESTED'
        )),

    CONSTRAINT pk_watch_events_partitioned
        PRIMARY KEY (watch_id, started_at),

    CONSTRAINT fk_watch_events_partitioned_user
        FOREIGN KEY (user_id)
        REFERENCES youtube.users(user_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_watch_events_partitioned_video
        FOREIGN KEY (video_id)
        REFERENCES youtube.videos(video_id)
        ON DELETE RESTRICT
)
PARTITION BY RANGE (started_at);

-- 2025 monthly partitions
CREATE TABLE youtube.watch_events_p2025_01 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-02-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_02 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-02-01 00:00:00+05:30') TO ('2025-03-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_03 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-03-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_04 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-05-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_05 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-05-01 00:00:00+05:30') TO ('2025-06-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_06 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-06-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_07 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-08-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_08 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-08-01 00:00:00+05:30') TO ('2025-09-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_09 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-09-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_10 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2025-11-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_11 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-11-01 00:00:00+05:30') TO ('2025-12-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2025_12 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2025-12-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');


-- 2026 monthly partitions (through the observed latest month)
CREATE TABLE youtube.watch_events_p2026_01 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-02-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2026_02 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2026-02-01 00:00:00+05:30') TO ('2026-03-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2026_03 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2026-03-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2026_04 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-05-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2026_05 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2026-05-01 00:00:00+05:30') TO ('2026-06-01 00:00:00+05:30');
CREATE TABLE youtube.watch_events_p2026_06 PARTITION OF youtube.watch_events_partitioned
    FOR VALUES FROM ('2026-06-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');

-- Future or out-of-range events land here until new monthly partitions are added.
CREATE TABLE youtube.watch_events_p_default
    PARTITION OF youtube.watch_events_partitioned DEFAULT;

-- Indexes are created on the partitioned parent; PostgreSQL creates matching
-- indexes on its partitions.
CREATE INDEX idx_watch_events_part_user_time
    ON youtube.watch_events_partitioned (user_id, started_at DESC);

CREATE INDEX idx_watch_events_part_video_time
    ON youtube.watch_events_partitioned (video_id, started_at DESC);

ANALYZE youtube.watch_events_partitioned;

-- Partition-pruning demonstration.
-- The plan should reference only youtube.watch_events_p2026_06, not all
-- monthly partitions, because the WHERE range matches June 2026 only.
SET enable_partition_pruning = on;

EXPLAIN (COSTS OFF)
SELECT count(*)
FROM youtube.watch_events_partitioned
WHERE started_at >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND started_at <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30';

