

SET search_path TO youtube;

-- 1. Users
\copy users FROM 'large_data/users.csv' WITH (FORMAT csv, HEADER true)

-- 2. Channels
\copy channels FROM 'large_data/channels.csv' WITH (FORMAT csv, HEADER true)

-- 3. Videos
\copy videos FROM 'large_data/videos.csv' WITH (FORMAT csv, HEADER true)

-- 4. Subscriptions
\copy subscriptions FROM 'large_data/subscriptions.csv' WITH (FORMAT csv, HEADER true)

-- 5. Watch events
\copy watch_events FROM 'large_data/watch_events.csv' WITH (FORMAT csv, HEADER true)

-- 6. Video reactions
\copy video_reactions FROM 'large_data/video_reactions.csv' WITH (FORMAT csv, HEADER true)

-- 7. Comments
\copy comments FROM 'large_data/comments.csv' WITH (FORMAT csv, HEADER true)

-- 8. Playlists
\copy playlists FROM 'large_data/playlists.csv' WITH (FORMAT csv, HEADER true)

-- 9. Playlist items
\copy playlist_items FROM 'large_data/playlist_items.csv' WITH (FORMAT csv, HEADER true)

-- 10. Ad impressions
\copy ad_impressions FROM 'large_data/ad_impressions.csv' WITH (FORMAT csv, HEADER true)

-- Update table statistics
ANALYZE;
