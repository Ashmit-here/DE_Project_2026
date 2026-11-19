-- ============================================================
-- YouTube DBMS Project - Phase 4: Query Optimization
-- File: sql/05_indexes.sql
-- Database: PostgreSQL 15+
-- ============================================================

SET search_path TO youtube;

-- ------------------------------------------------------------
-- 1. CHANNEL VIDEOS AND SUBSCRIPTIONS
-- Supports: R01, R03
-- Equality filters first, followed by ordering column.
-- ------------------------------------------------------------

CREATE INDEX idx_videos_channel_visibility_published
ON videos (channel_id, visibility, published_at DESC)
INCLUDE (video_id, title, duration_sec, view_count);

CREATE INDEX idx_subscriptions_channel_user
ON subscriptions (channel_id, user_id)
INCLUDE (subscribed_at);

-- ------------------------------------------------------------
-- 2. TITLE SEARCH
-- Supports: R04
-- Trigram GIN index supports ILIKE '%tutorial%'.
-- Partial index contains only public videos.
-- ------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_videos_title_trgm_public
ON videos USING GIN (title gin_trgm_ops)
WHERE visibility = 'PUBLIC';

-- ------------------------------------------------------------
-- 3. WATCH HISTORY AND VIDEO ANALYTICS
-- Supports: R05, R07, R08, R09, R13, R17, R19
-- ------------------------------------------------------------

CREATE INDEX idx_watch_events_user_started
ON watch_events (user_id, started_at DESC)
INCLUDE (video_id, watch_seconds);

CREATE INDEX idx_watch_events_video_user
ON watch_events (video_id, user_id)
INCLUDE (watch_seconds, traffic_source);

-- ------------------------------------------------------------
-- 4. TIME-BASED WATCH ANALYTICS
-- Supports: R07, R10, R11, R20
-- Useful for date-range filtering and video joins.
-- ------------------------------------------------------------

CREATE INDEX idx_watch_events_started_video
ON watch_events (started_at, video_id)
INCLUDE (watch_seconds);

-- ------------------------------------------------------------
-- 5. SCHEDULED VIDEO PUBLISHING
-- Supports: R06, W05
-- Partial index avoids indexing unrelated videos.
-- ------------------------------------------------------------

CREATE INDEX idx_videos_scheduled_published
ON videos (published_at)
WHERE visibility = 'SCHEDULED';

-- ------------------------------------------------------------
-- 6. SHORTS
-- Supports: R10
-- Smaller index containing only Shorts.
-- ------------------------------------------------------------

CREATE INDEX idx_videos_shorts
ON videos (video_id)
WHERE is_short = TRUE;

-- ------------------------------------------------------------
-- 7. VIDEO REACTIONS
-- Supports: R14
-- Finds reactions for each video and helps aggregate
-- LIKE and DISLIKE counts.
-- ------------------------------------------------------------

CREATE INDEX idx_video_reactions_video_reaction
ON video_reactions (video_id, reaction);

-- ------------------------------------------------------------
-- 8. COMMENTS
-- Supports: R15, R18, R23
-- ------------------------------------------------------------

CREATE INDEX idx_comments_video_top_level
ON comments (
    video_id,
    is_pinned DESC,
    like_count DESC
)
INCLUDE (comment_id, user_id)
WHERE parent_comment_id IS NULL;

CREATE INDEX idx_comments_video
ON comments (video_id);

CREATE INDEX idx_comments_created
ON comments (created_at DESC)
INCLUDE (comment_id, video_id, user_id);

-- ------------------------------------------------------------
-- 9. AD IMPRESSIONS AND FINANCE
-- Supports: R16, R25
-- Date filtering first, followed by watch lookup.
-- ------------------------------------------------------------

CREATE INDEX idx_ad_impressions_shown_watch
ON ad_impressions (shown_at, watch_id)
INCLUDE (revenue_inr);

-- ------------------------------------------------------------
-- 10. CHANNEL REPORTING
-- Supports: R17, R19
-- ------------------------------------------------------------

CREATE INDEX idx_videos_channel
ON videos (channel_id)
INCLUDE (video_id, uploaded_at);

-- ------------------------------------------------------------
-- 11. COPYRIGHT REPORTING
-- Supports: R22
-- Helps grouping by title and duration.
-- ------------------------------------------------------------

CREATE INDEX idx_videos_title_duration_channel
ON videos (title, duration_sec, channel_id);

-- ------------------------------------------------------------
-- 12. MONTHLY SUBSCRIBER REPORTING
-- Supports: R24
-- ------------------------------------------------------------

CREATE INDEX idx_subscriptions_channel_date
ON subscriptions (channel_id, subscribed_at);

-- ------------------------------------------------------------
-- 13. CHILD SAFETY REPORTING
-- Supports: R18
-- Partial index for made-for-kids videos.
-- ------------------------------------------------------------

CREATE INDEX idx_videos_made_for_kids
ON videos (video_id)
WHERE is_made_for_kids = TRUE;

-- ------------------------------------------------------------
-- Update planner statistics after index creation.
-- ------------------------------------------------------------

ANALYZE;

-- ============================================================
-- END OF INDEX DEFINITIONS
-- ============================================================
