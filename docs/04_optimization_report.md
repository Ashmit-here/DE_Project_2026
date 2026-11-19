# Phase 4 – Query Optimization Report

**Project:** YouTube Video Sharing Database  
**Team:** T0086  
**Database:** PostgreSQL (`youtube_db`, schema `youtube`)  
**Dataset:** Seed dataset (200,000 watch events)

---

## 1. Objective

The objective of Phase 4 was to optimize the 30-query workload while preserving the original results, except for R13, where the original query was found to return an incorrect result because of SQL `NULL` semantics.

The work included:

- Creating workload-oriented indexes in `sql/05_indexes.sql`.
- Rewriting selected queries in `sql/06_optimized_queries.sql`.
- Benchmarking all 30 queries.
- Comparing execution plans and timings.
- Verifying rewritten query results.
- Measuring write overhead and index storage.

The original `queries/workload_30.sql` was not modified.

## 2. Benchmark methodology

The benchmark script uses `EXPLAIN (ANALYZE, BUFFERS)` and records execution plans and timings. Write queries run inside transactions that are rolled back so benchmark runs do not permanently change the data.

As specified in the project brief:

- **Baseline:** 3 runs per query.
- **Optimized:** 5 runs per query.
- All timings below are average execution times in milliseconds.
- The same laptop and seed database were used.

Improvement is calculated as:

\[
\text{Improvement \%} =
\frac{\text{Baseline average} - \text{Optimized average}}
{\text{Baseline average}} \times 100
\]

The baseline and optimized run counts differ because the project brief specifies different run counts for the two phases. Therefore, the comparison is useful for measuring the workload but is not a perfectly controlled equal-sample comparison.

## 3. Optimization results for all 30 queries

| Query | Before (ms) | Problem found in baseline plan | Optimization applied / optimized plan | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|---|
| R01 | 3.663 | Sequential scan of videos for channel and visibility lookup | Covering composite index on channel, visibility and publication time | 0.145 | 96.0% | Yes |
| R02 | 0.053 | Primary-key lookups already efficient | No rewrite; existing primary-key lookups retained | 0.100 | -88.7% | Yes |
| R03 | 4.129 | Sequential scan of videos for subscriptions feed | Covering video index and subscription lookup index | 0.279 | 93.2% | Yes |
| R04 | 9.335 | Sequential scan for `ILIKE '%tutorial%'` | `pg_trgm` GIN partial index for public video titles | 1.739 | 81.4% | Yes |
| R05 | 5.682 | Sequential scan of watch events for user history | Index on `(user_id, started_at DESC)` with included columns | 0.209 | 96.3% | Yes |
| R06 | 2.115 | Sequential scan for scheduled videos | Partial index on scheduled videos by publication time | 0.055 | 97.4% | Yes |
| R07 | 9.859 | Sequential scans; `DATE()` applied to timestamp filter | Half-open timestamp range and supporting indexes | 0.705 | 92.8% | Yes — verified |
| R08 | 5.439 | Sequential scan of watch events for one video | Index on `(video_id, user_id)` | 0.093 | 98.3% | Yes |
| R09 | 8.341 | Sequential scans of watch events and videos | Channel/video and video/user indexes | 0.145 | 98.3% | Yes |
| R10 | 8.448 | Sequential scans for recent Shorts views | Partial Shorts index and timestamp/video index | 2.163 | 74.4% | Yes |
| R11 | 14.795 | Broad watch-event aggregation and category ranking | Timestamp index helps restrict watch events; aggregation remains | 9.207 | 37.8% | Yes |
| R12 | 10.964 | Full-table device aggregation | Sequential scan remains appropriate | 11.763 | -7.3% | Yes |
| R13 | 13.460 | `NOT IN` affected by NULL values; original returned no rows | Replaced `NOT IN` with correlated `NOT EXISTS` | 0.185 | 98.6%* | No — intentional correctness fix |
| R14 | 8.408 | Sequential scans of reactions and videos | Channel/video and `(video_id, reaction)` indexes | 0.406 | 95.2% | Yes |
| R15 | 2.325 | Sequential scan of comments | Video/top-level comment indexes | 0.083 | 96.4% | Yes |
| R16 | 13.108 | Broad scans for ad revenue aggregation | Ad-impression date/watch index; broad aggregation remains | 12.528 | 4.4% | Yes |
| R17 | 12.166 | Broad aggregation across channels, videos and watch events | Channel/video and video/user indexes | 22.859 | -87.9%** | Yes |
| R18 | 9.761 | Sequential scans of comments and videos | Partial made-for-kids index and comment indexes | 1.684 | 82.7% | Yes |
| R19 | 12,146.673 | Correlated subqueries repeatedly scanned videos and watch events | Grouped CTEs calculate latest upload and views once per channel | 41.706 | 99.7% | Yes — verified |
| R20 | 9.012 | `started_at::date` prevented direct timestamp range filtering | Half-open timestamp range; date grouping retained | 1.638 | 81.8% | Yes — verified |
| R21 | 0.211 | Primary-key lookup already efficient | No rewrite; existing primary-key indexes retained | 0.171 | 19.0% | Yes |
| R22 | 37.225 | Sequential scan of all videos before grouping | Covering index on `(title, duration_sec, channel_id)` | 4.049 | 89.1% | Yes |
| R23 | 14.000 | Deep `OFFSET 30000` pagination and comments scan | Index on `created_at DESC` supports ordering | 2.780 | 80.1% | Yes |
| R24 | 1.471 | Existing primary-key index not aligned with channel/date grouping | Index on `(channel_id, subscribed_at)` | 0.162 | 89.0% | Yes |
| R25 | 29.795 | Broad audit joins and sequential scans | Ad-impression date/watch index; broad audit still reads many rows | 28.201 | 5.3% | Yes |
| W01 | 0.843 | Insert requires maintenance of additional video indexes | Index maintenance on inserted video rows | 1.129 | -33.9% | Yes |
| W02 | 0.761 | Insert requires maintenance of watch-event indexes | Index maintenance on inserted watch event | 0.855 | -12.4% | Yes |
| W03 | 0.571 | Update incurs additional index maintenance | No query rewrite | 0.811 | -42.0% | Yes |
| W04 | 31.169 | Broad subscriber-count recomputation | No SQL rewrite; broad scans remain | 27.307 | 12.4% | Yes |
| W05 | 2.111 | Sequential scan to locate scheduled videos | Partial index on scheduled videos | 1.112 | 47.3% | Yes |

\* R13's percentage is a timing comparison only. Its original result was incorrect, so the result sets are intentionally different.

\** R17's optimized mean is affected by one high outlier (64.367 ms). Its baseline median was 12.002 ms and optimized median was 12.674 ms.

### 3.1 Aggregate timing

| Measure | Baseline | Optimized |
|---|---:|---:|
| Sum of 30 query averages | 12,415.893 ms | 174.269 ms |
| Reduction | | **98.6%** |

The aggregate reduction is dominated by R19, which fell from 12,146.673 ms to 41.706 ms after eliminating repeated correlated scans.

Excluding R19, the other 29 queries improved by approximately **50.8%** based on their summed averages.

- 24 queries had lower optimized averages.
- 6 queries had higher optimized averages: R02, R12, R17, W01, W02 and W03.
- W04 and W05 became faster.

The 98.6% figure represents the reduction in the sum of this workload's query averages. It does not mean every query became 98.6% faster.

## 4. Before/after EXPLAIN plan analysis

The following five comparisons use the saved baseline and optimized plan evidence.

### 4.1 R19 – Partner report

**Average:** 12,146.673 ms → 41.706 ms  
**Improvement:** 99.7% (approximately 291×)

**Before:**
- Sequential scan of `channels`.
- Correlated subqueries repeatedly scanned `videos`.
- Correlated subqueries repeatedly scanned `watch_events`.
- The repeated work was performed for eligible channels, resulting in very high execution time.

**After:**
- `latest_uploads` computes the latest upload once per channel.
- `channel_views` computes total views once per channel.
- The final query joins the grouped results to eligible channels.
- The captured plan uses hash joins and sequential scans of `watch_events`, `videos` and `channels` for the grouped work.

**Conclusion:** The improvement comes primarily from eliminating repeated correlated subqueries. The optimized R19 plan still uses sequential scans; it would be inaccurate to attribute this improvement to index scans.

### 4.2 R07 – Channel 217 daily views and watch hours

**Average:** 9.859 ms → 0.705 ms  
**Improvement:** 92.8% (approximately 14×)

**Before:**
- Sequential scans of `watch_events` and `videos`.
- The filter applied `DATE()` to `w.started_at`, preventing a direct timestamp range lookup.

**After:**
- The filter uses:
  `w.started_at >= DATE '2026-06-01' AND w.started_at < DATE '2026-07-01'`.
- The captured plan uses a bitmap index scan on `idx_watch_events_video_user`, a bitmap heap scan on `watch_events`, and an index-only scan for the channel lookup on `videos`.
- The first optimized run was 2.612 ms; later runs were approximately 0.213–0.241 ms. The first-run outlier raises the five-run average to 0.705 ms.

**Conclusion:** Keeping the timestamp column unwrapped in the filter allows PostgreSQL to use the index for the date-constrained lookup.

### 4.3 R04 – Public title search

**Average:** 9.335 ms → 1.739 ms  
**Improvement:** 81.4% (approximately 5.4×)

**Before:**
- Sequential scan of `videos` evaluated the substring search predicate.

**After:**
- Bitmap index scan on `idx_videos_title_trgm_public`.
- Bitmap heap scan on `videos`.
- The index is a GIN trigram index restricted to public videos.

**Conclusion:** `pg_trgm` supports substring matching such as `ILIKE '%tutorial%'`, where a conventional B-tree index is unsuitable.

### 4.4 R22 – Duplicate title/duration copyright report

**Average:** 37.225 ms → 4.049 ms  
**Improvement:** 89.1% (approximately 9.2×)

**Before:**
- Sequential scan of all 30,000 videos followed by grouping.

**After:**
- Index-only scan on `idx_videos_title_duration_channel`.
- The index contains `title`, `duration_sec` and `channel_id`.
- The plan performs a `GroupAggregate`, applies the distinct-channel count filter and uses a top-N heapsort for the requested 50 rows.
- The captured plan reported 703 heap fetches.

**Conclusion:** The covering index supplies the grouping data from the index and reduces the cost of reading the videos table.

### 4.5 R10 – Shorts shelf

**Average:** 8.448 ms → 2.163 ms  
**Improvement:** 74.4% (approximately 3.9×)

**Before:**
- Sequential scans of `watch_events` and `videos`.

**After:**
- Index-only scan using `idx_watch_events_started_video`.
- Index scan using `idx_videos_shorts`.
- The join and aggregation are still required to count views per Short.

**Conclusion:** The partial index limits the video-side lookup to Shorts, while the timestamp/video index supports the recent watch-event range. The remaining join and aggregation explain why this query still takes longer than point lookups.

## 5. Correctness verification

The Phase 4 brief requires result checks for rewritten queries. Bidirectional `EXCEPT ALL` comparisons were executed against the current seed database. This checks for missing and additional rows, including duplicate-row differences.

| Query | Check | Observed result | Conclusion |
|---|---|---:|---|
| R07 | Original vs optimized in both `EXCEPT ALL` directions | 0 differences | Exact match |
| R19 | Original vs optimized in both `EXCEPT ALL` directions | 0 differences | Exact match |
| R20 | Original vs optimized in both `EXCEPT ALL` directions | 0 differences | Exact match |
| R13 | NULL diagnostic and row-count comparison | 24 NULL user IDs among 97 watch rows; original returned 0 rows; corrected returned 88 rows | Intentional correctness correction |

The remaining workload queries were not rewritten; their SQL statements were retained and only the index environment changed.

### 5.1 R13 – The `NOT IN` NULL problem

The original R13 query used:

```sql
s.user_id NOT IN (
    SELECT w.user_id
    FROM watch_events w
    JOIN videos v ON v.video_id = w.video_id
    WHERE v.channel_id = 217
)
```

The diagnostic query found **24 NULL `user_id` values among 97 watch rows** for channel 217.

In SQL, if a `NOT IN` list contains a NULL and no equal value is found, the predicate can evaluate to `UNKNOWN`, not `TRUE`. A `WHERE` clause retains only rows for which the predicate is true. Consequently, the original query returned zero rows in this dataset.

The optimized query uses:

```sql
AND NOT EXISTS (
    SELECT 1
    FROM watch_events w
    JOIN videos v ON v.video_id = w.video_id
    WHERE v.channel_id = 217
      AND w.user_id = s.user_id
)
```

This checks whether a matching watch row exists for each subscriber. A NULL `w.user_id` does not match a non-NULL subscriber ID and does not poison the result for all subscribers.

**Observed counts:**

| Version | Rows returned |
|---|---:|
| Original `NOT IN` query | 0 |
| Corrected `NOT EXISTS` query | 88 |

R13 is an intentional correction of a wrong result, not a result-preserving optimization.

## 6. Write overhead

Indexes improve reads but must also be maintained when rows are inserted or updated.

| Write query | Baseline avg (ms) | Optimized avg (ms) | Change (ms) | Relative change |
|---|---:|---:|---:|---:|
| W01 – Insert video | 0.843 | 1.129 | +0.286 | 33.9% slower |
| W02 – Insert watch event | 0.761 | 0.855 | +0.094 | 12.4% slower |
| W03 – Increment view counter | 0.571 | 0.811 | +0.240 | 42.0% slower |
| W04 – Recompute subscriber counts | 31.169 | 27.307 | -3.862 | 12.4% faster |
| W05 – Publish scheduled videos | 2.111 | 1.112 | -0.999 | 47.3% faster |

W01, W02 and W03 became slower, but each absolute increase was below 0.3 ms on this seed workload. This is a reasonable trade-off for the read improvements measured here, subject to the actual production read/write ratio.

W04 and W05 did not become slower in these measurements.

These timings measure the total effect of the Phase 4 index set; they do not isolate the cost of any individual index.

## 7. Index storage

The following sizes were collected using PostgreSQL relation-size measurements. The percentage is:

\[
\text{Index/table ratio} =
\frac{\text{Index size}}{\text{Table size}} \times 100
\]

Only the **17 custom indexes created for Phase 4** are listed. Existing primary-key and unique indexes are not counted as new Phase 4 indexes.

| Custom index | Index size | Table | Table size | Index/table |
|---|---:|---|---:|---:|
| `idx_ad_impressions_shown_watch` | 2,264 kB | `ad_impressions` | 3,808 kB | 59.45% |
| `idx_comments_created` | 2,928 kB | `comments` | 5,824 kB | 50.27% |
| `idx_comments_video` | 1,152 kB | `comments` | 5,824 kB | 19.78% |
| `idx_comments_video_top_level` | 3,048 kB | `comments` | 5,824 kB | 52.34% |
| `idx_subscriptions_channel_date` | 4,008 kB | `subscriptions` | 7,552 kB | 53.07% |
| `idx_subscriptions_channel_user` | 4,000 kB | `subscriptions` | 7,552 kB | 52.97% |
| `idx_video_reactions_video_reaction` | 1,576 kB | `video_reactions` | 4,096 kB | 38.48% |
| `idx_videos_channel` | 1,200 kB | `videos` | 5,184 kB | 23.15% |
| `idx_videos_channel_visibility_published` | 2,960 kB | `videos` | 5,184 kB | 57.10% |
| `idx_videos_made_for_kids` | 32 kB | `videos` | 5,184 kB | 0.62% |
| `idx_videos_scheduled_published` | 16 kB | `videos` | 5,184 kB | 0.31% |
| `idx_videos_shorts` | 248 kB | `videos` | 5,184 kB | 4.78% |
| `idx_videos_title_duration_channel` | 1,640 kB | `videos` | 5,184 kB | 31.64% |
| `idx_videos_title_trgm_public` | 1,656 kB | `videos` | 5,184 kB | 31.94% |
| `idx_watch_events_started_video` | 7,936 kB | `watch_events` | 16 MB | 47.88% |
| `idx_watch_events_user_started` | 9,704 kB | `watch_events` | 16 MB | 58.54% |
| `idx_watch_events_video_user` | 10,152 kB | `watch_events` | 16 MB | 61.25% |

The largest storage costs are the three watch-event indexes. This is expected because `watch_events` is the largest table and supports several important access paths.

The two partial video indexes, `idx_videos_made_for_kids` and `idx_videos_scheduled_published`, are very small because they contain only qualifying rows.

The indexes add meaningful storage, particularly on `watch_events`, `subscriptions`, `comments` and `ad_impressions`. This is the trade-off for faster reads. Index sizes and write amplification should be monitored on the larger dataset rather than assuming the seed-data ratios will remain constant.

## 8. Queries with limited or no improvement

Not every query benefits from an index. The query shape and execution plan explain several exceptions:

- **R02:** A primary-key lookup and channel primary-key lookup were already very fast. The change from 0.053 ms to 0.100 ms is small in absolute terms and can be affected by timing variation.
- **R12:** The query groups every watch event by device and calculates the logged-out percentage. It must inspect the watch-event rows, so a sequential scan is reasonable.
- **R16:** The finance report aggregates ad impressions by channel over a month. The optimized plan still performs broad work on watch events and related rows; improvement was only 4.4%.
- **R17:** The partner eligibility report joins and aggregates a large share of channels, videos and watch events. The optimized mean was affected by a 64.367 ms run; the median changed from 12.002 ms to 12.674 ms.
- **R19:** The optimized query is much faster but still uses sequential scans. This is reasonable for grouped totals over a large fraction of the source tables. Its improvement comes from doing grouped work once rather than once per channel.
- **R25:** The Premium audit is a broad reporting query joining ads, watch events and users. The date index helps, but much of the data still has to be examined.
- **R11:** The query still needs to count views and rank videos within categories. Indexing helps restrict the watch-event date range, but cannot remove aggregation and ranking work.
- **W01–W03:** These are small writes. Maintaining extra indexes can cost more than the tiny amount of lookup work saved, so a modest slowdown is expected.

The goal is not to force an index scan for every query. PostgreSQL's sequential scan is often the best plan when a query reads a large proportion of a table.

## 9. Index-to-query coverage

| Index | Main workload supported | Reason for index shape |
|---|---|---|
| `idx_videos_channel_visibility_published` | R01, R03, R14 | Equality filters on channel and visibility precede publication ordering; included columns cover common output |
| `idx_subscriptions_channel_user` | R03, R13 | Channel/user lookup with `subscribed_at` available from the index |
| `idx_videos_title_trgm_public` | R04 | Trigram GIN index supports substring `ILIKE`; partial predicate limits it to public videos |
| `idx_watch_events_user_started` | R05 and user/time-oriented event access | User equality followed by descending event time; included columns cover history output |
| `idx_watch_events_video_user` | R08, R09, R13 | Video equality and user lookup; included watch fields support reporting |
| `idx_watch_events_started_video` | R07, R10, R11, R20 | Timestamp-leading index supports time-window filtering and carries video ID for joins |
| `idx_videos_scheduled_published` | R06, W05 | Partial index stores only scheduled videos and orders by publication time |
| `idx_videos_shorts` | R10 | Partial index stores only Shorts |
| `idx_video_reactions_video_reaction` | R14 | Video equality followed by reaction type supports per-video like/dislike aggregation |
| `idx_comments_video_top_level` | R15, R18, R23 | Partial index for top-level comments, ordered by pinned and like count |
| `idx_comments_video` | R15, R18, R23 | Direct video-to-comment lookup and existence checks |
| `idx_comments_created` | R23 | Descending creation-time order supports newest-first moderation retrieval |
| `idx_ad_impressions_shown_watch` | R16, R25 | Date-leading lookup with watch ID join and revenue included |
| `idx_videos_channel` | R17, R19 | Channel-to-video lookup with video ID and upload time available |
| `idx_videos_title_duration_channel` | R22 | Covers grouping keys and channel ID for distinct-channel counting |
| `idx_subscriptions_channel_date` | R24 | Channel equality followed by subscription timestamp for monthly grouping |
| `idx_videos_made_for_kids` | R18 | Partial index stores only made-for-kids videos |

`ANALYZE` is run after index creation so PostgreSQL can plan using refreshed statistics.

## 10. Conclusion

Phase 4 produced substantial improvements for the seed-data workload. The largest gain came from rewriting R19 to eliminate repeated correlated subqueries. The timestamp-range rewrites in R07 and R20 made date filters index-friendly, and the trigram, partial and covering indexes improved several common lookup and reporting patterns.

The summed average execution time across the 30 queries decreased from 12,415.893 ms to 174.269 ms (98.6%). This aggregate is heavily influenced by R19; excluding R19, the other 29 queries improved by approximately 50.8%.

Twenty-four query averages improved, while six increased. The absolute write overhead on W01–W03 was below 0.3 ms per query in these measurements, while W04 and W05 became faster.

Correctness checks confirmed exact output equality for R07, R19 and R20 on the tested database. R13 exposed the required `NOT IN`/`NULL` bug: the original returned zero rows, while the corrected `NOT EXISTS` version returned 88 valid subscribers. This is documented as a deliberate correctness repair rather than an identical-result rewrite.

The Phase 4 indexes add storage and write-maintenance costs, particularly on the large `watch_events` table. Phase 5 must validate these choices against the 20× dataset, monitor index growth and write amplification, and investigate queries that miss the Phase 5 performance targets.

## 11. Reproducibility and deliverables

Phase 4 files:

- `sql/05_indexes.sql` – custom indexes and `ANALYZE`.
- `sql/06_optimized_queries.sql` – optimized workload, preserving the query markers.
- `benchmarks/results/optimized/summary.csv` – optimized averages, medians, ranges and scan-node summaries.
- `benchmarks/results/optimized/` – raw plan files for the optimized workload.
- `docs/04_optimization_report.md` – this report.

The baseline comparison uses `benchmarks/results/baseline/summary.csv` and its saved raw plans. The original workload remains in `queries/workload_30.sql` and should not be edited.