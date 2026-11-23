# Phase 5: Scalability Report

**Project:** YouTube Video Sharing Database  
**Team:** T0086  
**Database:** PostgreSQL  
**Benchmark:** Three runs per query; averages reported in milliseconds

## 1. Large-dataset setup

The large database was created separately as `youtube_large`. The original schema was loaded, the large CSV data was imported, the Phase 4 indexes were applied, and statistics were refreshed with `ANALYZE`. The optimized workload `sql/06_optimized_queries.sql` was benchmarked; the original workload was not run on the large database.

The loaded row counts were:

| Table | Rows |
|---|---:|
| users | 600,000 |
| channels | 60,000 |
| videos | 600,000 |
| subscriptions | 2,598,598 |
| watch_events | 4,000,000 |
| video_reactions | 1,350,452 |
| comments | 1,200,000 |
| playlists | 160,000 |
| playlist_items | 1,120,003 |
| ad_impressions | 1,139,137 |

The `watch_events` data ranges from **2025-01-01 00:00:00+05:30** to **2026-06-30 23:59:48+05:30**.

## 2. Large-dataset benchmark results

The table compares the Phase 4 optimized seed averages with the Phase 5 large-data averages. Growth is calculated as `large average / seed average`. Targets are from the project brief.

| Query | Optimized seed (ms) | Optimized large (ms) | Growth | Target | Met? |
|---|---:|---:|---:|---:|:---:|
| R01 | 0.145 | 0.119 | 0.82× | < 5 ms | Yes |
| R02 | 0.100 | 0.523 | 5.23× | < 5 ms | Yes |
| R03 | 0.279 | 0.453 | 1.62× | < 5 ms | Yes |
| R04 | 1.739 | 36.283 | 20.86× | < 250 ms | Yes |
| R05 | 0.209 | 0.480 | 2.30× | < 5 ms | Yes |
| R06 | 0.055 | 0.543 | 9.87× | < 250 ms | Yes |
| R07 | 0.705 | 2.345 | 3.33× | < 250 ms | Yes |
| R08 | 0.093 | 0.077 | 0.83× | < 250 ms | Yes |
| R09 | 0.145 | 0.445 | 3.07× | < 250 ms | Yes |
| R10 | 2.163 | 21.913 | 10.13× | < 5,000 ms | Yes |
| R11 | 9.207 | 175.416 | 19.05× | < 5,000 ms | Yes |
| R12 | 11.763 | 153.688 | 13.07× | < 5,000 ms | Yes |
| R13 | 0.185 | 0.593 | 3.21× | < 250 ms | Yes |
| R14 | 0.406 | 1.001 | 2.47× | < 250 ms | Yes |
| R15 | 0.083 | 0.030 | 0.36× | < 5 ms | Yes |
| R16 | 12.528 | 163.305 | 13.04× | < 5,000 ms | Yes |
| R17 | 22.859 | 210.822 | 9.22× | < 5,000 ms | Yes |
| R18 | 1.684 | 21.665 | 12.87× | < 5,000 ms | Yes |
| R19 | 41.706 | 561.715 | 13.47× | < 5,000 ms | Yes |
| R20 | 1.638 | 39.378 | 24.04× | < 5,000 ms | Yes |
| R21 | 0.171 | 0.218 | 1.27× | < 5 ms | Yes |
| R22 | 4.049 | 65.463 | 16.17× | < 5,000 ms | Yes |
| R23 | 2.780 | 3.154 | 1.13× | < 5,000 ms | Yes |
| R24 | 0.162 | 0.298 | 1.84× | < 250 ms | Yes |
| R25 | 28.201 | 409.057 | 14.51× | < 5,000 ms | Yes |
| W01 | 1.129 | 1.568 | 1.39× | < 5 ms | Yes |
| W02 | 0.855 | 1.213 | 1.42× | < 5 ms | Yes |
| W03 | 0.811 | 0.908 | 1.12× | < 5 ms | Yes |
| W04 | 27.307 | 605.186 | 22.16× | < 2,000 ms | Yes |
| W05 | 1.112 | 14.366 | 12.92× | < 250 ms | Yes |

All **30 of 30 queries met their target** on the large dataset.

The largest measured query average was R19 at **561.715 ms**, below the 5,000 ms analytics target. W04, the batch subscriber-count recomputation, took **605.186 ms**, below its 2,000 ms target. The slowest interactive query was R04 at **36.283 ms**, below 250 ms.

The sum of the 30 query averages was **174.269 ms** on the seed dataset and **2,492.225 ms** on the large dataset, a ratio of approximately **14.30×**. This is the sum of separate query averages, not the latency of one application request.

## 3. Growth analysis

The row count of `watch_events` increased from 200,000 to 4,000,000 (20×). Query times did not all grow at the same rate.

### 3.1 Stayed approximately the same or improved (under 2×)

R01 (0.82×), R03 (1.62×), R08 (0.83×), R15 (0.36×), R21 (1.27×), R23 (1.13×), R24 (1.84×), W01 (1.39×), W02 (1.42×), and W03 (1.12×) stayed below 2×.

These queries generally retrieve a limited number of rows or use selective lookups and indexes. Values below 1× should not be interpreted as the larger database being inherently faster; sub-millisecond timings are sensitive to cache state and normal benchmark variation.

### 3.2 Grew between 2× and 20×

R02 (5.23×), R05 (2.30×), R06 (9.87×), R07 (3.33×), R09 (3.07×), R10 (10.13×), R11 (19.05×), R12 (13.07×), R13 (3.21×), R14 (2.47×), R16 (13.04×), R17 (9.22×), R18 (12.87×), R19 (13.47×), R22 (16.17×), R25 (14.51×), and W05 (12.92×) increased, but remained within their respective latency targets.

Several of these queries aggregate or join more rows as the database grows. Their absolute execution times, rather than the growth ratio alone, determine whether the required service target is met.

### 3.3 Grew more than 20×

| Query | Growth | Large average | Interpretation |
|---|---:|---:|---|
| R04 | 20.86× | 36.283 ms | Title search and ordering do more work as the video catalogue grows. |
| R20 | 24.04× | 39.378 ms | Daily watch-hour aggregation reads and groups the selected watch-event range. |
| W04 | 22.16× | 605.186 ms | Recomputing subscriber counts touches the larger subscriptions dataset. |

These are the main queries to monitor as volume grows further. **None breached its Phase 5 target**, so no scale-only query rewrite was required for this benchmark round. The growth ratios identify candidates for future work; they do not by themselves prove a particular plan operator caused the increase.

## 4. What broke at scale and fixes

No query crossed its assigned performance target in the large-data benchmark. Therefore, no large-data query rewrite was applied after the Phase 4 optimized workload, and there are no scale-specific before/after plans to claim.

The following are monitoring priorities for the next growth step:

- **R19:** highest analytics latency at 561.715 ms. Consider a maintained per-channel summary of latest upload and total views if the report becomes more frequent.
- **R25:** 409.057 ms. Keep the Premium-ad audit indexed on the time and join keys; consider a time-partitioned audit table if ad-impression volume becomes substantially larger.
- **W04:** 605.186 ms. At higher scale, maintain subscriber counts incrementally from subscription insert/delete events instead of repeatedly recomputing every channel.
- **R04:** 36.283 ms. Retain the title-search index strategy and monitor search latency as the video catalogue grows.

These are future design recommendations, not fixes already applied or benchmarked.

## 5. Storage comparison

### 5.1 Seed database (`youtube_db`)

| Table | Table size | Index size | Total relation size |
|---|---:|---:|---:|
| watch_events | 16 MB | 31 MB | 48 MB |
| subscriptions | 7,552 kB | 11 MB | 18 MB |
| comments | 5,824 kB | 8,456 kB | 14 MB |
| videos | 5,184 kB | 8,688 kB | 14 MB |
| video_reactions | 4,096 kB | 3,664 kB | 7,792 kB |
| ad_impressions | 3,808 kB | 3,528 kB | 7,368 kB |
| playlist_items | 3,296 kB | 2,976 kB | 6,304 kB |
| users | 2,688 kB | 2,888 kB | 5,608 kB |
| channels | 288 kB | 496 kB | 816 kB |
| playlists | 576 kB | 192 kB | 800 kB |

**Seed database size:** 129 MB.

### 5.2 Large database (`youtube_large`)

| Table | Table size | Index size | Total relation size |
|---|---:|---:|---:|
| watch_events | 319 MB | 627 MB | 946 MB |
| subscriptions | 140 MB | 212 MB | 352 MB |
| comments | 108 MB | 164 MB | 272 MB |
| videos | 100 MB | 155 MB | 254 MB |
| video_reactions | 78 MB | 71 MB | 149 MB |
| ad_impressions | 75 MB | 68 MB | 143 MB |
| playlist_items | 65 MB | 58 MB | 122 MB |
| users | 52 MB | 60 MB | 112 MB |
| playlists | 11 MB | 3,536 kB | 15 MB |
| channels | 5,712 kB | 7,152 kB | 13 MB |

**Large database size:** 2,386 MB (approximately 2.33 GB).

The database size increased from 129 MB to 2,386 MB, approximately **18.50×**. The `watch_events` indexes alone occupy 627 MB, nearly twice the 319 MB table size. This shows that indexes are a significant part of the storage budget and should be justified by query usage.

The per-table relation totals do not necessarily add up exactly to the database size because database-level storage also includes other relation and metadata overhead.

## 6. Architecture proposal for 100× growth

### 6.1 Partitioning

Partition **`watch_events` by RANGE on `started_at`, monthly**.

Reasons:

- The measured data spans 18 calendar months, from January 2025 through June 2026.
- Time-based analytics such as R07, R10, R11, R16, and R20 filter on event timestamps.
- Monthly partitions allow PostgreSQL to prune irrelevant months for time-bounded queries.
- Old partitions can be archived or detached without deleting individual rows.

The DDL is provided in `sql/08_partitioning.sql`. It creates a separate demonstration table named `youtube.watch_events_partitioned`, monthly partitions for the observed range, a default partition, and user/video time indexes. It ends with an `EXPLAIN` query restricted to June 2026; the plan should scan only the June partition.

**Primary-key rule:** PostgreSQL requires a primary key or unique constraint on a partitioned table to include the partition key. The example therefore uses `(watch_id, started_at)`. This does not enforce global uniqueness of `watch_id` alone. The existing `ad_impressions.watch_id` foreign key would also need to be redesigned to reference the composite key (by storing the event timestamp too), or use a separate non-partitioned watch-ID registry. The demo DDL intentionally does not alter the current benchmark schema or its foreign keys.

### 6.2 Sharding

For a future distributed deployment, use **channel-based hash sharding within time partitions** as the initial design.

A watch event belongs to a video, and each video belongs to a channel. Routing events by the owning `channel_id` keeps a creator's videos and their watch events together, which benefits Studio and channel-level reports such as R07, R09, R17, and R19.

Trade-off: a user's watch history (R05) can span channels and therefore shards. That query would need a fan-out read across shards, followed by a merge ordered by `started_at`. A small routing directory or user-to-shard activity index can help locate a user's recent events. Logged-out events still have a video and channel, so they can be routed using the video-to-channel mapping.

This is a proposed architecture, not a sharding implementation tested in this project.

### 6.3 Read replicas and caching

- **Read replicas:** Send analytics and reporting reads (R07–R20 and R22–R25) to replicas when a small replication delay is acceptable. Heavy reports should not compete with transactional writes on the primary.
- **Viewer reads:** R01, R02, R03, R05, R15, and R21 can use replicas when slightly stale results are acceptable. Read-after-write cases, such as a newly uploaded video or a just-updated playlist, should use the primary or a consistency-aware routing rule.
- **Cache candidates:** Cache channel/video metadata for R01 and R02, playlist page results for R21, and popular search results for R04 with short expiration or invalidation on updates. Trending and Studio aggregates (R10, R11, R20, R24) can use refreshed summary data if the product accepts a defined freshness window.
- **Primary-only writes:** W01, W02, W03, W04, and W05 must execute on the primary database. Replicas receive their changes through replication.

### 6.4 Maintenance

- Run `ANALYZE` after bulk loads and monitor statistics freshness on high-ingest tables.
- Keep autovacuum enabled. Tune table-specific vacuum and analyze thresholds for `watch_events` using observed insert/update/delete rates and dead-tuple statistics rather than applying untested global settings.
- Monitor index growth and bloat, especially on `watch_events`, whose large-dataset indexes occupy 627 MB.
- With monthly partitions, archive or detach partitions outside the online retention window according to product and compliance requirements.
- Maintain summary tables or materialized views for expensive creator and finance aggregates where a documented refresh delay is acceptable.
- Refresh summaries incrementally where possible; schedule full refreshes outside peak traffic and monitor their runtime.

## 7. Conclusion

The optimized workload met **all 30 Phase 5 performance targets** on the 4-million-watch-event dataset. The database occupied approximately **2.33 GB**, and the total size was about **18.50×** the seed database.

The results support the current design for the tested 20× dataset, but they do not prove readiness for every 100× workload. The main risks are growth in watch-event indexes, aggregation cost, repeated full subscriber-count recomputation, cross-shard user history, and the foreign-key implications of partitioning. Monthly time partitioning, carefully selected shard routing, replicas, caching, and monitored maintenance provide a practical next-step architecture.
