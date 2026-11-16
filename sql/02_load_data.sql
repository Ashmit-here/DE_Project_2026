

SET search_path TO youtube;

-- 1. Users
\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)

-- 2. Channels
\copy channels FROM 'seed_data/channels.csv' WITH (FORMAT csv, HEADER true)

-- 3. Videos
\copy videos FROM 'seed_data/videos.csv' WITH (FORMAT csv, HEADER true)

-- 4. Subscriptions
\copy subscriptions FROM 'seed_data/subscriptions.csv' WITH (FORMAT csv, HEADER true)

-- 5. Watch events
\copy watch_events FROM 'seed_data/watch_events.csv' WITH (FORMAT csv, HEADER true)

-- 6. Video reactions
\copy video_reactions FROM 'seed_data/video_reactions.csv' WITH (FORMAT csv, HEADER true)

-- 7. Comments
\copy comments FROM 'seed_data/comments.csv' WITH (FORMAT csv, HEADER true)

-- 8. Playlists
\copy playlists FROM 'seed_data/playlists.csv' WITH (FORMAT csv, HEADER true)

-- 9. Playlist items
\copy playlist_items FROM 'seed_data/playlist_items.csv' WITH (FORMAT csv, HEADER true)

-- 10. Ad impressions
\copy ad_impressions FROM 'seed_data/ad_impressions.csv' WITH (FORMAT csv, HEADER true)

-- Update table statistics
ANALYZE;
