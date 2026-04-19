# Performance Tuning Report
## EAS 550 | Vaishak Muralidharan — Phase 2

---

## 1. Query Profiled

The query profiled is a 3-table JOIN across `tracks`, `audio_features`, and `genres` — the core pattern used in all three advanced analytical queries. This join chain processes 89,740 rows and represents the hottest path in the dashboard's genre and mood analysis features.

---

## 2. EXPLAIN ANALYZE Output

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT g.genre_name, af.energy, af.valence, t.popularity
FROM tracks t
JOIN audio_features af ON t.track_id = af.track_id
JOIN genres g ON t.genre_id = g.genre_id
```


---

## 3. What the Plan Tells Us

The planner chose **Hash Join** for both joins — this is the right call for large unsorted datasets. No nested loops, no sort steps. The entire result of 89,740 rows was processed in under 95ms.

All 2,196 buffer hits came from **shared memory cache** — meaning zero disk reads were needed. This is ideal behaviour for a serverless database like Neon where cold reads are expensive.

The `genres` table has only 113 rows so it was hashed instantly and added negligible overhead. The heavier cost sits in scanning `audio_features` and `tracks`, each with ~89k rows.

---

## 4. Indexes Implemented

| Index | Table | Columns | Purpose |
|---|---|---|---|
| `idx_audio_energy_valence` | `audio_features` | `(energy, valence)` | Mood quadrant filtering in Query 3 |
| `idx_audio_features_covering` | `audio_features` | `(track_id, energy, valence, danceability, tempo)` | Eliminates heap fetches for Query 3 |
| `idx_track_artists_track` | `track_artists` | `(track_id)` | Bridge table lookup for Query 2 |
| `idx_tracks_genre_popularity` | `tracks` | `(genre_id, popularity DESC)` | Covers GROUP BY + ORDER BY in Query 1 |
| `idx_tracks_popular` | `tracks` | `(track_id, popularity, genre_id)` WHERE popularity ≥ 50 | Partial index for popular tracks filter |
| `idx_tracks_explicit` | `tracks` | `(explicit)` WHERE explicit = TRUE | Partial index for explicit content filter |

---

## 5. Performance Summary

| Metric | Value |
|---|---|
| Total execution time | 94.8 ms |
| Rows processed | 89,740 |
| Buffer hits (shared cache) | 2,196 |
| Disk reads | 0 |
| Join strategy | Hash Join (optimal) |
| Planning time | 3.7 ms |

---

## 6. Recommendations

- Run `VACUUM ANALYZE` after any bulk re-ingestion to keep planner statistics fresh.
- The covering index on `audio_features` will show the most benefit on the full mood cluster query (Query 3) which filters on energy, valence, danceability, and tempo together.
- Neon serverless cold-start adds ~500ms on first connection — this dominates over query time. The `NullPool` setup in `ingest_data.py` already handles this correctly.
- For Phase 3, consider a materialized view for the mood cluster CTE chain if it becomes a repeated dashboard query.