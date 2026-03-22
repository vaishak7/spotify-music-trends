# 3NF Design Justification Report
**EAS 550 — Group Project Phase 1**  
**Student:** Vaishak Muralidharan  
**Project:** Spotify Music Trends Analysis  

---

## 1. Source Data Overview

The raw dataset is a flat CSV file with **114,000 rows** and **21 columns**, sourced from Kaggle. Every row represents a single track appearance in a genre category, meaning the same `track_id` can appear multiple times (once per genre). Key observations from the raw data:

- `artists` stores multiple artists as a semicolon-delimited string (e.g. `"Ingrid Michaelson;ZAYN"`), violating atomicity.
- `track_genre` is a plain string repeated across thousands of rows.
- `album_name` is a plain string repeated across all tracks in the same album.
- Audio feature columns (danceability, energy, loudness, etc.) are mixed with identity columns (track name, artist, album) in a single row.

---

## 2. Identified Entities and Relationships

After analyzing the raw data, six entities were identified:

| Entity | Description |
|---|---|
| `genres` | Lookup table for the 114 unique genre labels |
| `artists` | One row per unique artist name |
| `albums` | One row per unique album name |
| `tracks` | Core fact table — identity and categorical attributes |
| `audio_features` | Continuous acoustic measurements (1-to-1 with tracks) |
| `track_artists` | Bridge table resolving tracks ↔ artists many-to-many |

---

## 3. Normalization Steps

### First Normal Form (1NF)
The raw CSV violated 1NF because the `artists` column stored multiple values in a single cell using semicolon delimiters. This was resolved by:
- Creating an `artists` table with one row per artist.
- Creating a `track_artists` bridge table to link tracks to their artists atomically.

### Second Normal Form (2NF)
2NF requires no partial dependencies on a composite key. Since `tracks` uses `track_id` as a single-column primary key, partial dependencies are not applicable here. However, the raw CSV had genre and album name embedded in every track row — these attributes depend only on their own entity, not on `track_id`. They were moved to their own tables (`genres`, `albums`).

### Third Normal Form (3NF)
3NF requires no transitive dependencies — non-key columns must depend only on the primary key, not on other non-key columns.

In the raw CSV, `track_genre` (a non-key column) could imply attributes like "genre category" or "genre family." By isolating it into a `genres` table, any future attributes of a genre would be stored there, not transitively through the track. Similarly, `album_name` was extracted so that album-level metadata (future: release year, label) lives in the `albums` table rather than being repeated in every track row.

The `audio_features` table was separated from `tracks` to avoid a situation where acoustic attributes (which describe how a track sounds) are mixed with identity attributes (which describe what a track is). Both groups depend fully on `track_id`, satisfying 3NF, but separating them improves clarity and query performance for dashboard visualizations.

---

## 4. Resolving Many-to-Many Relationships

The most significant many-to-many relationship is **tracks ↔ artists**:
- One track can have multiple artists (e.g. a collaboration).
- One artist can appear on many tracks.

This was resolved with the `track_artists` bridge table, which holds `(track_id, artist_id)` pairs with a composite primary key to prevent duplicates.

---

## 5. How the Schema Avoids Data Anomalies

| Anomaly | How the schema prevents it |
|---|---|
| **Insertion anomaly** | Genre and artist data can be added independently without needing a track first. |
| **Update anomaly** | A genre name change only requires updating one row in `genres`, not thousands of track rows. |
| **Deletion anomaly** | Deleting a track does not delete the artist or genre from the system. Foreign key `ON DELETE SET NULL` / `ON DELETE CASCADE` handles cleanup safely. |
| **Duplication** | `UNIQUE` constraints on `genre_name` and `artist_name` prevent the same value being stored twice with different IDs. |

---

## 6. Schema Diagram (Summary)

```
genres ──< tracks >── albums
              │
         audio_features (1:1)
              │
         track_artists >── artists
```

- `genres` → `tracks`: one genre, many tracks (FK: `genre_id`)
- `albums` → `tracks`: one album, many tracks (FK: `album_id`)
- `tracks` → `audio_features`: one-to-one (shared PK)
- `tracks` ↔ `artists`: many-to-many via `track_artists` bridge

---

## 7. Data Type Choices

| Column | Type | Reason |
|---|---|---|
| `track_id` | `TEXT` | Spotify IDs are alphanumeric strings, not integers |
| `popularity` | `SMALLINT` | Integer 0–100, enforced by CHECK constraint |
| `danceability` etc. | `DECIMAL(5,4)` | 4 decimal places match Spotify API precision (e.g. 0.6760) |
| `loudness` | `DECIMAL(6,3)` | Can be negative (e.g. -17.235 dB), needs sign + 3 decimals |
| `tempo` | `DECIMAL(6,3)` | BPM values like 87.917 require decimal precision |
| `explicit` | `BOOLEAN` | Binary flag, no other values possible |
