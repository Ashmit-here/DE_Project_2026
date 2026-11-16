# Phase 2: Database Schema Design

## 1. Objective

The objective is to reconstruct a normalized and well-constrained PostgreSQL database using the 10 supplied CSV files.

The database must:
- Preserve all records from the supplied seed data.
- Maintain correct relationships between tables.
- Prevent invalid and duplicate data.
- Support YouTube's viewing, publishing, subscription, playlist, and monetization features.
- Provide a foundation for query optimization and future scalability.

The database will use PostgreSQL 15 or newer. All tables will be created inside the `youtube` schema.

## 2. Database Tables and Data Dictionary

### 2.1 users

**Source:** `users.csv`

Stores information about registered YouTube users.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| user_id | INTEGER | PRIMARY KEY, NOT NULL | Uniquely identifies each user. |
| email | VARCHAR(255) | NOT NULL, UNIQUE | Email addresses must be unique. |
| display_name | VARCHAR(100) | NOT NULL | Stores the user's display name. |
| country_code | CHAR(2) | NOT NULL, CHECK | Stores a two-letter country code. |
| birth_year | SMALLINT | NULL, CHECK | Birth year may be unavailable. |
| premium_until | TIMESTAMPTZ | NULL | Premium expiry may be unavailable. |
| created_at | TIMESTAMPTZ | NOT NULL | Records account creation time. |

**Design decisions:**
- `user_id` is the primary key because it uniquely identifies a user and does not depend on changeable personal information.
- `email` is a unique candidate key but is not used as the primary key.
- `birth_year` and `premium_until` allow NULL values because some users do not have these details.

### 2.2 channels

**Source:** `channels.csv`

Stores creator channel information. Each channel belongs to one user.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| channel_id | INTEGER | PRIMARY KEY, NOT NULL | Uniquely identifies a channel. |
| owner_user_id | INTEGER | NOT NULL, FOREIGN KEY | Identifies the channel owner. |
| handle | VARCHAR(30) | NOT NULL, UNIQUE | Each channel has a unique handle. |
| channel_name | VARCHAR(100) | NOT NULL | Stores the channel's display name. |
| country_code | CHAR(2) | NOT NULL, CHECK | Stores the channel's country. |
| is_verified | BOOLEAN | NOT NULL, DEFAULT FALSE | Indicates verification status. |
| monetization_status | VARCHAR(20) | NOT NULL, DEFAULT 'NOT_ELIGIBLE', CHECK | Restricts monetization status to valid values. |
| subscriber_count | INTEGER | NOT NULL, DEFAULT 0, CHECK | Stores the subscriber count. |
| created_at | TIMESTAMPTZ | NOT NULL | Records channel creation time. |

**Foreign key:** `owner_user_id` references `users(user_id)`.

**Design decisions:**
- A user can own multiple channels, but each channel has one owner.
- `subscriber_count` is a derived or cached value because it can be calculated from the subscriptions table. It is retained for faster channel-page access, with consistency checks required when subscriptions change.
- Channel ownership should not be silently deleted. Use `ON DELETE RESTRICT` for the owner foreign key.

### 2.3 videos

**Source:** `videos.csv`

Stores uploaded videos, including long videos and Shorts.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| video_id | VARCHAR(11) | PRIMARY KEY, NOT NULL, CHECK | Every video has an 11-character ID. |
| channel_id | INTEGER | NOT NULL, FOREIGN KEY | Identifies the uploading channel. |
| title | VARCHAR(100) | NOT NULL | Stores the video title. |
| description | TEXT | NULL | A description may not be provided. |
| category | VARCHAR(20) | NOT NULL, CHECK | Restricts videos to supported categories. |
| duration_sec | INTEGER | NOT NULL, CHECK | Stores video duration in seconds. |
| is_short | BOOLEAN | NOT NULL | Indicates whether the video is a Short. |
| is_made_for_kids | BOOLEAN | NOT NULL, DEFAULT FALSE | Indicates child-directed content. |
| visibility | VARCHAR(10) | NOT NULL, CHECK | Controls video visibility and publishing status. |
| uploaded_at | TIMESTAMPTZ | NOT NULL | Records upload time. |
| published_at | TIMESTAMPTZ | NULL | May be empty for private videos. |
| view_count | BIGINT | NOT NULL, DEFAULT 0, CHECK | Stores the video's view count. |

**Foreign key:** `channel_id` references `channels(channel_id)`.

**Design decisions:**
- `video_id` uses `VARCHAR(11)` rather than an integer because video IDs are alphanumeric.
- `description` allows NULL because descriptions are optional.
- `published_at` allows NULL for private videos.
- `view_count` is a derived or cached value that can be compared with watch-event data.
- `is_short` is related to video duration, but is retained as an explicit product classification. Its consistency with `duration_sec` must be validated.

### 2.4 subscriptions

**Source:** `subscriptions.csv`

Stores which users subscribe to which channels.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| user_id | INTEGER | PRIMARY KEY (composite), FOREIGN KEY, NOT NULL | Identifies the subscribing user. |
| channel_id | INTEGER | PRIMARY KEY (composite), FOREIGN KEY, NOT NULL | Identifies the subscribed channel. |
| notifications | VARCHAR(15) | NOT NULL, CHECK | Stores the notification preference. |
| subscribed_at | TIMESTAMPTZ | NOT NULL | Records when the subscription began. |

**Composite primary key:** `(user_id, channel_id)`.

**Foreign keys:**
- `user_id` references `users(user_id)`.
- `channel_id` references `channels(channel_id)`.

**Design decisions:**
- Users can subscribe to multiple channels.
- Channels can have multiple subscribers.
- The combination of user and channel prevents duplicate subscriptions.
- This table resolves the many-to-many relationship between users and channels.

### 2.5 watch_events

**Source:** `watch_events.csv`

Stores viewing activity, including views from logged-in and logged-out viewers.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| watch_id | BIGINT | PRIMARY KEY, NOT NULL | Uniquely identifies each viewing event. |
| user_id | INTEGER | NULL, FOREIGN KEY | Logged-out viewers do not have a user ID. |
| video_id | VARCHAR(11) | NOT NULL, FOREIGN KEY | Identifies the watched video. |
| started_at | TIMESTAMPTZ | NOT NULL | Records when viewing started. |
| watch_seconds | INTEGER | NOT NULL, CHECK | Stores viewing duration in seconds. |
| device | VARCHAR(10) | NOT NULL, CHECK | Stores the viewing device. |
| traffic_source | VARCHAR(20) | NOT NULL, CHECK | Identifies how the viewer reached the video. |

**Foreign keys:**
- `user_id` references `users(user_id)` with `ON DELETE SET NULL`.
- `video_id` references `videos(video_id)` with `ON DELETE RESTRICT`.

**Design decisions:**
- `user_id` must allow NULL because logged-out viewers also generate watch events.
- Watch events are important for analytics and view counts, so deleting a video should not accidentally delete its viewing history.

### 2.6 video_reactions

**Source:** `video_reactions.csv`

Stores likes and dislikes given by users.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| user_id | INTEGER | PRIMARY KEY (composite), FOREIGN KEY, NOT NULL | Identifies the user giving the reaction. |
| video_id | VARCHAR(11) | PRIMARY KEY (composite), FOREIGN KEY, NOT NULL | Identifies the video receiving the reaction. |
| reaction | VARCHAR(10) | NOT NULL, CHECK | Allows LIKE or DISLIKE. |
| reacted_at | TIMESTAMPTZ | NOT NULL | Records when the reaction was made. |

**Composite primary key:** `(user_id, video_id)`.

**Foreign keys:**
- `user_id` references `users(user_id)`.
- `video_id` references `videos(video_id)`.

**Design decisions:**
- A user can react to many videos.
- A video can receive reactions from many users.
- The composite key ensures that a user has at most one current reaction per video.

### 2.7 comments

**Source:** `comments.csv`

Stores comments and replies posted on videos.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| comment_id | BIGINT | PRIMARY KEY, NOT NULL | Uniquely identifies a comment. |
| video_id | VARCHAR(11) | NOT NULL, FOREIGN KEY | Identifies the video being commented on. |
| user_id | INTEGER | NOT NULL, FOREIGN KEY | Identifies the comment author. |
| parent_comment_id | BIGINT | NULL, SELF-REFERENCING FOREIGN KEY | Connects replies to their parent comments. |
| body | TEXT | NOT NULL | Stores the comment text. |
| like_count | INTEGER | NOT NULL, DEFAULT 0, CHECK | Stores the number of likes. |
| is_pinned | BOOLEAN | NOT NULL, DEFAULT FALSE | Indicates whether a comment is pinned. |
| created_at | TIMESTAMPTZ | NOT NULL | Records comment creation time. |

**Foreign keys:**
- `video_id` references `videos(video_id)`.
- `user_id` references `users(user_id)`.
- `parent_comment_id` references `comments(comment_id)`.

**Design decisions:**
- `parent_comment_id` allows NULL for comments that are not replies.
- The self-referencing foreign key supports comment threads.
- A comment must not reference itself as its parent.
- Replies should not be pinned if that is the rule confirmed by the project data and business requirements.

### 2.8 playlists

**Source:** `playlists.csv`

Stores playlists created by registered users.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| playlist_id | INTEGER | PRIMARY KEY, NOT NULL | Uniquely identifies a playlist. |
| owner_user_id | INTEGER | NOT NULL, FOREIGN KEY | Identifies the playlist owner. |
| title | VARCHAR(150) | NOT NULL | Stores the playlist title. |
| visibility | VARCHAR(10) | NOT NULL, CHECK | Controls playlist visibility. |
| created_at | TIMESTAMPTZ | NOT NULL | Records playlist creation time. |

**Foreign key:** `owner_user_id` references `users(user_id)`.

**Design decisions:**
- One user can create multiple playlists.
- Playlist visibility is restricted to PUBLIC, UNLISTED, or PRIVATE.
- A playlist belongs to one user.

### 2.9 playlist_items

**Source:** `playlist_items.csv`

Stores the videos contained in playlists and their order.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| playlist_id | INTEGER | PRIMARY KEY (composite), FOREIGN KEY, NOT NULL | Identifies the playlist. |
| position | SMALLINT | PRIMARY KEY (composite), NOT NULL, CHECK | Defines the video's position in the playlist. |
| video_id | VARCHAR(11) | NOT NULL, FOREIGN KEY, UNIQUE with playlist_id | Identifies the added video. |
| added_at | TIMESTAMPTZ | NOT NULL | Records when the video was added. |

**Composite primary key:** `(playlist_id, position)`.

**Additional unique constraint:** `(playlist_id, video_id)`.

**Foreign keys:**
- `playlist_id` references `playlists(playlist_id)`.
- `video_id` references `videos(video_id)`.

**Design decisions:**
- A playlist can contain multiple videos.
- A video can appear in multiple playlists.
- The composite primary key ensures that two videos cannot occupy the same position in one playlist.
- The additional unique constraint prevents the same video from being added twice to the same playlist.
- Position must be a positive number.

### 2.10 ad_impressions

**Source:** `ad_impressions.csv`

Stores advertisements displayed during video views and the revenue earned.

| Column | Data type | Constraints | Reason |
|---|---|---|---|
| impression_id | BIGINT | PRIMARY KEY, NOT NULL | Uniquely identifies an ad impression. |
| watch_id | BIGINT | NOT NULL, FOREIGN KEY | Identifies the viewing event during which the ad appeared. |
| ad_format | VARCHAR(10) | NOT NULL, CHECK | Restricts the ad format to supported values. |
| revenue_inr | NUMERIC(10,4) | NOT NULL, CHECK | Stores ad revenue accurately in INR. |
| shown_at | TIMESTAMPTZ | NOT NULL | Records when the ad was displayed. |

**Foreign key:** `watch_id` references `watch_events(watch_id)` with `ON DELETE RESTRICT`.

**Design decisions:**
- `NUMERIC(10,4)` is used for revenue because financial values require exact decimal representation.
- `ON DELETE RESTRICT` protects revenue records from accidental deletion of their associated watch events.

## 3. Primary Keys and Foreign Keys Summary

| Table | Primary key | Foreign key relationships |
|---|---|---|
| users | user_id | None |
| channels | channel_id | owner_user_id → users |
| videos | video_id | channel_id → channels |
| subscriptions | user_id + channel_id | user_id → users; channel_id → channels |
| watch_events | watch_id | user_id → users; video_id → videos |
| video_reactions | user_id + video_id | user_id → users; video_id → videos |
| comments | comment_id | video_id → videos; user_id → users; parent_comment_id → comments |
| playlists | playlist_id | owner_user_id → users |
| playlist_items | playlist_id + position | playlist_id → playlists; video_id → videos |
| ad_impressions | impression_id | watch_id → watch_events |

## 4. Relationships and Cardinalities

| Relationship | Cardinality | Explanation |
|---|---|---|
| users → channels | One-to-many | One user can own multiple channels. |
| channels → videos | One-to-many | One channel can upload multiple videos. |
| users ↔ channels | Many-to-many | Users subscribe to channels through subscriptions. |
| users ↔ videos | Many-to-many | Users react to videos through video_reactions. |
| users → watch_events | One-to-many, optional | A signed-in user can generate multiple watch events; logged-out events have no user. |
| videos → watch_events | One-to-many | A video can have multiple viewing events. |
| videos → comments | One-to-many | A video can have multiple comments. |
| comments → comments | One-to-many, recursive | A comment can have multiple replies. |
| users → playlists | One-to-many | A user can create multiple playlists. |
| playlists ↔ videos | Many-to-many | Videos are added to playlists through playlist_items. |
| watch_events → ad_impressions | One-to-many | A watch event can have multiple ad impressions. |

## 5. Check Constraints

The following checks will be implemented where supported by the source data and business rules. Every constraint must be tested against the complete seed data before the load is considered successful.

| No. | Table | Constraint rule |
|---|---|---|
| 1 | users | Country code must contain exactly two uppercase letters. |
| 2 | users | Birth year must be within a valid range when provided. |
| 3 | channels | Country code must contain exactly two uppercase letters. |
| 4 | channels | Handle must begin with `@` and contain only permitted handle characters. |
| 5 | channels | Monetization status must be ELIGIBLE, NOT_ELIGIBLE, or SUSPENDED. |
| 6 | channels | Subscriber count must be non-negative. |
| 7 | videos | Video ID must contain exactly 11 characters. |
| 8 | videos | Category must be one of Comedy, Cooking, Education, Film, Gaming, Music, News, Sports, Tech, or Vlogs. |
| 9 | videos | Duration must be greater than zero. |
| 10 | videos | Visibility must be PUBLIC, UNLISTED, PRIVATE, or SCHEDULED. |
| 11 | videos | A private video must not have a published_at value. |
| 12 | videos | A Short must have a duration of at most 60 seconds. |
| 13 | videos | View count must be non-negative. |
| 14 | subscriptions | Notifications must be ALL, NONE, or PERSONALIZED. |
| 15 | watch_events | Watch duration must be non-negative. |
| 16 | watch_events | Device must be WEB, ANDROID, IOS, or TV. |
| 17 | watch_events | Traffic source must be HOME, SEARCH, SUGGESTED, SUBSCRIPTION, SHORTS_FEED, or EXTERNAL. |
| 18 | video_reactions | Reaction must be LIKE or DISLIKE. |
| 19 | comments | Like count must be non-negative. |
| 20 | comments | A comment cannot have itself as its parent. |
| 21 | playlists | Visibility must be PUBLIC, UNLISTED, or PRIVATE. |
| 22 | playlist_items | Position must be greater than or equal to 1. |
| 23 | ad_impressions | Ad format must be PREROLL or MIDROLL. |
| 24 | ad_impressions | Revenue must be non-negative. |

Some cross-table rules, such as ensuring that watch duration does not exceed video duration or that an ad is not shown to a Premium member, require validation queries or additional application logic rather than a simple row-level CHECK constraint.

## 6. Normalization and Functional Dependencies

The proposed design aims to satisfy Third Normal Form (3NF).

A functional dependency describes how one or more columns determine other columns in a table.

| Table | Functional dependency |
|---|---|
| users | user_id → email, display_name, country_code, birth_year, premium_until, created_at |
| channels | channel_id → owner_user_id, handle, channel_name, country_code, is_verified, monetization_status, subscriber_count, created_at |
| videos | video_id → channel_id, title, description, category, duration_sec, is_short, is_made_for_kids, visibility, uploaded_at, published_at, view_count |
| subscriptions | (user_id, channel_id) → notifications, subscribed_at |
| watch_events | watch_id → user_id, video_id, started_at, watch_seconds, device, traffic_source |
| video_reactions | (user_id, video_id) → reaction, reacted_at |
| comments | comment_id → video_id, user_id, parent_comment_id, body, like_count, is_pinned, created_at |
| playlists | playlist_id → owner_user_id, title, visibility, created_at |
| playlist_items | (playlist_id, position) → video_id, added_at |
| ad_impressions | impression_id → watch_id, ad_format, revenue_inr, shown_at |

### Normalization explanation

**First Normal Form (1NF):**
- Every table has a primary key.
- Each column stores a single value.
- Repeating groups are represented using separate relationship tables.

**Second Normal Form (2NF):**
- Tables with composite primary keys have non-key attributes that depend on the complete key.
- For example, in subscriptions, notifications and subscribed_at depend on both user_id and channel_id.

**Third Normal Form (3NF):**
- Non-key attributes should depend on the key, the whole key, and nothing but the key.
- User details are stored in users rather than repeated in channels, videos, or comments.
- Channel details are stored separately from videos.
- Relationship-specific information is stored in the relevant junction tables.

### Derived and potentially redundant columns

| Column | Why it is derived or redundant | Design decision |
|---|---|---|
| channels.subscriber_count | Can be calculated by counting subscriptions for a channel. | Retain as a cached value for faster channel-page reads; maintain consistency. |
| videos.view_count | Can be calculated by counting watch events for a video. | Retain as a cached counter for faster reads; maintain consistency. |
| videos.is_short | Related to the duration of the video. | Retain as an explicit product classification and validate against the duration rule. |

These values are retained because they can improve read performance, but their correctness must be maintained when underlying records change.

## 7. Referential Integrity and Deletion Rules

The following deletion behavior is proposed:

- Deleting a user should not silently delete their channels or historical viewing records. Restrict deletion where necessary.
- Deleting a channel should not silently remove its videos. Restrict deletion while dependent records exist.
- Deleting a video should not silently erase watch history or financial records. Restrict deletion where historical records depend on it.
- Deleting a user may set `watch_events.user_id` to NULL to preserve anonymous viewing history.
- Deleting a playlist can cascade to its playlist_items because those items have no independent meaning without the playlist.
- Deleting a comment may cascade to its replies if the entire comment thread is being removed.
- Deleting a watch event must be restricted when ad impression records depend on it.

The final ON DELETE actions must be implemented consistently in `sql/01_schema.sql`.

## 8. Data Loading and Validation

The ten CSV files will be loaded into PostgreSQL using `\copy`.

Parent tables must be loaded before their dependent tables.

Recommended loading order:

1. users
2. channels
3. videos
4. subscriptions
5. watch_events
6. video_reactions
7. comments
8. playlists
9. playlist_items
10. ad_impressions

After loading, the following expected row counts must be verified:

| Table | Expected rows |
|---|---:|
| users | 30,000 |
| channels | 3,000 |
| videos | 30,000 |
| subscriptions | 129,253 |
| watch_events | 200,000 |
| video_reactions | 67,417 |
| comments | 60,000 |
| playlists | 8,000 |
| playlist_items | 56,005 |
| ad_impressions | 57,014 |
| **Total** | **665,689** |

### Integrity checks to perform

1. Verify that every channel references an existing user.
2. Verify that every video references an existing channel.
3. Verify that every watch event references an existing video.
4. Verify that watch duration does not exceed the video's duration.
5. Verify that no playlist contains the same video twice.
6. Verify that every ad impression references an existing watch event.
7. Verify that all primary keys are unique and non-null.

The results of these checks will be added after the database has been created and the CSV files have been loaded. No successful validation is assumed before execution.

## 9. Indexing Decisions

During Phase 2, only indexes automatically created by PRIMARY KEY and UNIQUE constraints will exist.

No additional performance indexes will be created in this phase. This is important because Phase 3 requires measuring the baseline performance before query optimization.

Additional indexes will be considered in Phase 4 after examining the execution plans of the 30 supplied queries.

## 10. Conclusion

The proposed database consists of ten related tables reconstructed from the supplied YouTube seed data.

The design uses appropriate PostgreSQL data types, primary keys, foreign keys, unique constraints, NOT NULL rules, and CHECK constraints to maintain data integrity.

The schema will be validated against all supplied CSV records before it is used for query benchmarking and optimization.