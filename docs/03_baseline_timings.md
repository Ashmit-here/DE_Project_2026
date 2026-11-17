# Baseline Query Timings

**Database:** youtube

**Phase:** Baseline (Before Optimization)

**Runs per query:** 3

**Measurement:** EXPLAIN (ANALYZE, BUFFERS)

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Channel page: the 20 newest public videos of channel 217 | READ | 5.555 | 2.742 | 2.692 | 3.663 |
| R02: Watch page: one video with its channel | READ | 0.054 | 0.042 | 0.063 | 0.053 |
| R03: Subscriptions feed: public videos from channels user 1042 subscribes to, newest first | READ | 4.376 | 3.769 | 4.243 | 4.129 |
| R04: Search: public videos with "tutorial" in the title, most viewed first | READ | 10.053 | 8.713 | 9.240 | 9.335 |
| R05: History page: the last 50 videos user 1042 watched | READ | 6.646 | 5.216 | 5.185 | 5.682 |
| R06: Publishing service: videos scheduled to go live in the first week of July 2026 | READ | 1.888 | 2.346 | 2.112 | 2.115 |
| R07: YouTube Studio: channel 217's daily views and watch hours in June 2026 | READ | 10.433 | 9.990 | 9.154 | 9.859 |
| R08: YouTube Studio: where views of video ZkNSlUB1EOs come from | READ | 5.795 | 5.426 | 5.097 | 5.439 |
| R09: YouTube Studio: average percentage watched for each of channel 217's videos | READ | 8.893 | 8.123 | 8.006 | 8.341 |
| R10: Shorts shelf: most viewed Shorts in the last 7 days of June 2026 | READ | 8.671 | 8.348 | 8.325 | 8.448 |
| R11: Trending tab: top 5 videos per category by views in June 2026 | READ | 15.312 | 14.494 | 14.579 | 14.795 |
| R12: Growth: share of logged-out viewing per device type | READ | 11.390 | 10.736 | 10.765 | 10.964 |
| R13: Creator insights: subscribers of channel 217 who have never watched any of its videos | READ | 15.325 | 12.461 | 12.593 | 13.460 |
| R14: YouTube Studio: likes, dislikes and like ratio per video of channel 217 | READ | 8.903 | 8.080 | 8.242 | 8.408 |
| R15: Watch page: pinned comment and top 10 comments of video ZkNSlUB1EOs | READ | 2.569 | 2.205 | 2.201 | 2.325 |
| R16: Finance: ad revenue per channel in June 2026, top 20 | READ | 13.956 | 12.804 | 12.565 | 13.108 |
| R17: Partner program: NOT_ELIGIBLE channels that now have 100+ subscribers and 40+ watch hours | READ | 12.528 | 11.969 | 12.002 | 12.166 |
| R18: Child safety: "made for kids" videos that still have comments (comments must be disabled) | READ | 10.136 | 9.510 | 9.636 | 9.761 |
| R19: Partner report: for every monetized channel, its latest upload and its total views | READ | 12045.281 | 11994.050 | 12400.688 | 12146.673 |
| R20: Platform analytics: daily watch hours and running total for June 2026 | READ | 9.955 | 8.665 | 8.417 | 9.012 |
| R21: Playlist page: playlist 501 in order | READ | 0.452 | 0.091 | 0.089 | 0.211 |
| R22: Copyright team: same title and duration uploaded by more than one channel | READ | 37.774 | 37.248 | 36.652 | 37.225 |
| R23: Moderation queue: all comments, newest first, page 1,201 (25 per page) | READ | 15.405 | 13.429 | 13.167 | 14.000 |
| R24: YouTube Studio: new subscribers per month for channel 217 | READ | 1.627 | 1.393 | 1.392 | 1.471 |
| R25: Premium audit: ads that were shown to users with an active Premium membership | READ | 30.321 | 29.721 | 29.344 | 29.795 |
| W01: Upload: a new public video on channel 217 | WRITE | 1.621 | 0.467 | 0.442 | 0.843 |
| W02: Player: record a view of video ZkNSlUB1EOs by user 1042 | WRITE | 1.199 | 0.564 | 0.521 | 0.761 |
| W03: View counter: add one view to video ZkNSlUB1EOs | WRITE | 1.268 | 0.217 | 0.227 | 0.571 |
| W04: Nightly job: recompute every channel's subscriber count | WRITE | 29.744 | 33.365 | 30.397 | 31.169 |
| W05: Publishing service: make scheduled videos public once their time has come (run at 3 Jul 2026 00:00) | WRITE | 2.163 | 2.067 | 2.103 | 2.111 |
| **Total (sum of all 30)** | | | | | **12415.893** |

## Scan Types and Query Analysis

| Query | Scan Type | Why it is slow or fast |
|---|---|---|
| R01 | Seq Scan on videos | Scans the videos table sequentially to find the matching public videos. |
| R02 | Index Scan using videos_pkey on videos; Index Scan using channels_pkey on channels | Uses primary-key indexes to retrieve the video and its channel efficiently. |
| R03 | Seq Scan on videos; Index Only Scan using pk_subscriptions on subscriptions; Index Scan using channels_pkey on channels | Scans videos while using indexes for subscription and channel lookups. |
| R04 | Seq Scan on videos | Sequentially scans videos to apply the title and visibility filters. |
| R05 | Seq Scan on watch_events; Index Scan using videos_pkey on videos | Scans watch events and uses the video primary-key index for video details. |
| R06 | Seq Scan on videos | Sequentially scans videos to identify those scheduled in the requested date range. |
| R07 | Seq Scan on watch_events; Seq Scan on videos | Sequential scans of watch events and videos contribute to the query work. |
| R08 | Seq Scan on watch_events | Sequentially scans watch events to identify the video's traffic sources. |
| R09 | Seq Scan on watch_events; Seq Scan on videos | Scans watch events and videos to calculate viewing percentages. |
| R10 | Seq Scan on watch_events; Seq Scan on videos | Sequential scans are used to filter and rank the Shorts viewing data. |
| R11 | Seq Scan on watch_events; Seq Scan on videos | Scans viewing events and videos to calculate category-level rankings. |
| R12 | Seq Scan on watch_events | Sequentially scans watch events to group logged-out views by device type. |
| R13 | Index Scan using pk_subscriptions on subscriptions; Seq Scan on watch_events; Seq Scan on videos | Uses an index for subscriptions, but sequentially scans watch events and videos. |
| R14 | Seq Scan on video_reactions; Seq Scan on videos | Sequentially scans reactions and videos to calculate like and dislike statistics. |
| R15 | Seq Scan on comments | Sequentially scans comments to retrieve the requested comments. |
| R16 | Seq Scan on watch_events; Seq Scan on ad_impressions; Index Scan using videos_pkey on videos | Scans watch events and ad impressions, while using the video primary-key index. |
| R17 | Seq Scan on watch_events; Seq Scan on videos; Seq Scan on channels | Sequential scans across three tables contribute to the query's execution time. |
| R18 | Seq Scan on comments; Seq Scan on videos | Sequentially scans comments and videos to identify the matching records. |
| R19 | Seq Scan on channels; Seq Scan on videos; Seq Scan on watch_events | Sequential scans across three tables; this query has the highest average execution time. |
| R20 | Seq Scan on watch_events | Sequentially scans watch events to calculate daily and running watch-hour totals. |
| R21 | Index Scan using pk_playlist_items on playlist_items; Index Scan using videos_pkey on videos | Uses indexes on playlist items and videos, resulting in efficient lookups. |
| R22 | Seq Scan on videos | Sequentially scans videos to find matching titles and durations. |
| R23 | Seq Scan on comments | Sequentially scans comments to retrieve the requested page. |
| R24 | Index Scan using pk_subscriptions on subscriptions | Uses the subscription index to retrieve matching subscription records. |
| R25 | Seq Scan on watch_events; Seq Scan on ad_impressions; Seq Scan on users | Sequential scans across three tables contribute to the query's execution time. |
| W01 | No scan reported | The execution plan reports no scan nodes for this write operation. |
| W02 | No scan reported | The execution plan reports no scan nodes for this write operation. |
| W03 | Index Scan using videos_pkey on videos | Uses the video primary-key index to locate the target video. |
| W04 | Seq Scan on channels; Seq Scan on subscriptions | Sequentially scans channels and subscriptions while recomputing subscriber counts. |
| W05 | Seq Scan on videos | Sequentially scans videos to identify scheduled videos that should become public. |
