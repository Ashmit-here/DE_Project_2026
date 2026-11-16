# Phase 1: Problem Understanding

## Project Overview

YouTube needs a reliable and scalable database to support channels, videos, viewers, subscriptions, watch events, playlists, comments, and monetization. The existing database has no documented schema, making it difficult to support product features and business reporting efficiently.

The goal is to rebuild a well-constrained database, improve query performance without changing results, and prepare it for approximately 20× traffic growth.

## Business Problems and Stakeholders

| Problem | Business need and affected stakeholders | Classification |
|---|---|---|
| **P1 – Slow pages** | Viewers need channel pages, video watch pages, and playlists to load quickly. **Stakeholder:** Viewer app and viewers. | Customer-facing / real-time |
| **P2 – Slow feed and history** | Viewers need fast subscription feeds and watch-history access, especially active users. **Stakeholder:** Viewers. | Customer-facing / real-time |
| **P3 – Slow search** | Viewers need to find videos quickly using their titles. **Stakeholder:** Viewers and Search team. | Customer-facing / real-time |
| **P4 – Delayed Studio charts** | Creators need timely daily views, traffic sources, retention, likes, and subscriber-growth statistics. **Stakeholder:** Creators and YouTube Studio team. | Reporting / analytics |
| **P5 – Incorrect subscriber report** | Creators need an accurate list of subscribers who have never watched their channel. **Stakeholder:** Creators and YouTube Studio team. | Reporting / analytics |
| **P6 – Slow recommendations** | Shorts shelves and Trending content need to be refreshed efficiently so viewers see relevant and popular content. **Stakeholder:** Viewers and Recommendations team. | Customer-facing / real-time |
| **P7 – Publishing and counter delays** | Scheduled videos must publish at the correct time, uploads must remain responsive, and view counters must handle heavy traffic. **Stakeholder:** Creators, viewers, and Publishing team. | Customer-facing / real-time |
| **P8 – Finance report timeouts** | Ad revenue, Partner Program eligibility, and Premium ad-audit reports must be accurate and complete. **Stakeholder:** Finance and Partner Program teams; Premium subscribers are affected by correct ad handling. | Reporting / analytics |
| **P9 – Trust and growth reporting** | Teams need reports for child safety, copyright, moderation, logged-out viewers, and watch-time trends. The database must also support expected traffic growth. **Stakeholder:** Child Safety, Copyright, Moderation, and Growth teams. | Reporting / analytics |

## Assumptions

1. The available CSV exports represent the data that must be preserved during database reconstruction.
2. Every video has a unique 11-character ID and a valid visibility status: public, unlisted, private, or scheduled.
3. Both signed-in and logged-out viewers can generate watch events.
4. Only signed-in users can subscribe, react to videos, comment, and create playlists.
5. YouTube Premium members should not receive advertisements.
6. Scheduled videos should become available according to their configured publishing time.
7. The empty subscriber report in P5 may indicate a query or data-model issue; it does not necessarily mean that no such subscribers exist.
8. Performance improvements must not change the results of the required queries.
9. The database should be designed to accommodate approximately 20× traffic growth.

## Overall Objective

Build a normalized, accurate, and well-constrained PostgreSQL database that supports fast user-facing features, reliable publishing, accurate business reports, and future growth.