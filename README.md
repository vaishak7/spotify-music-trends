# Spotify Music Trends Analysis
## EAS 550 | Vaishak Muralidharan

---

## Project Description
Interactive data visualization dashboard exploring Spotify music trends across 114k tracks, 114 genres, and a fully normalized PostgreSQL schema hosted on Neon serverless.

---

## Phase 1 Files
| File | Description |
|------|-------------|
| `ERD_Spotify.png` | Entity Relationship Diagram (Crow's Foot notation) |
| `schema.sql` | OLTP database schema — all CREATE TABLE statements |
| `ingest_data.py` | Data cleaning and bulk ingestion pipeline (COPY method) |
| `security.sql` | Role-Based Access Control (analyst + app_user roles) |
| `3NF_justification_report.md` | Schema normalization justification |

---

## Phase 2 Files

### dbt Project (`spotify_dbt/`)
```
spotify_dbt/
├── dbt_project.yml              # dbt project config
├── profiles.yml                 # connection profile (uses env vars)
├── packages.yml                 # dbt-utils dependency
├── .sqlfluff                    # SQLFluff linting config
├── models/
│   ├── staging/
│   │   ├── sources.yml          # Source definitions + column-level tests
│   │   ├── stg_tracks.sql       # Cleaned tracks staging view
│   │   ├── stg_audio_features.sql # Audio features + derived buckets
│   │   ├── stg_artists.sql
│   │   ├── stg_albums.sql
│   │   └── stg_genres.sql
│   └── marts/
│       ├── schema.yml           # Mart model tests
│       ├── fact_tracks.sql      # ⭐ Central fact table (star schema)
│       ├── dim_artist.sql       # Artist dimension
│       ├── dim_genre.sql        # Genre dimension
│       └── dim_album.sql        # Album dimension
└── tests/
    ├── assert_no_orphaned_audio_features.sql
    ├── assert_popularity_range.sql
    └── assert_every_track_has_artist.sql
```

### CI/CD (`.github/workflows/`)
| File | Description |
|------|-------------|
| `.github/workflows/ci.yml` | GitHub Actions: SQLFluff lint → dbt run → dbt test → docs |

### Advanced SQL & Tuning
| File | Description |
|------|-------------|
| `advanced_query_1_genre_ranking.sql` | Genre popularity ranking — RANK(), PERCENT_RANK(), SUM OVER |
| `advanced_query_2_artist_performance_tiers.sql` | Artist tier classification — NTILE(), LAG(), CASE |
| `advanced_query_3_mood_clusters.sql` | Cross-genre mood cluster analysis — 5 CTEs, ROW_NUMBER(), FILTER |
| `indexes.sql` | Strategic indexes for query performance |
| `performance_tuning_report.md` | EXPLAIN ANALYZE results, before/after comparison |

---

## Star Schema Diagram

```
                          ┌─────────────┐
                          │  dim_genre  │
                          │─────────────│
                          │ genre_id PK │
                          │ genre_name  │
                          │ total_tracks│
                          │ avg_pop     │
                          └──────┬──────┘
                                 │
┌─────────────┐          ┌───────▼──────────────────────────────┐          ┌──────────────┐
│  dim_album  │          │             fact_tracks               │          │  dim_artist  │
│─────────────│          │───────────────────────────────────────│          │──────────────│
│ album_id PK │◄─────────│ track_id PK                           │          │ artist_id PK │
│ album_name  │          │ album_id FK ──────────────────────────►──────────│ artist_name  │
│ total_tracks│          │ genre_id FK                           │  (via    │ total_tracks │
│ avg_pop     │          │ track_name                            │  artist_ │ avg_pop      │
│ total_dur   │          │ popularity                            │  names   │ peak_pop     │
└─────────────┘          │ duration_ms / _seconds                │  field)  └──────────────┘
                         │ explicit, key, mode                   │
                         │ artist_names (denorm)                 │
                         │ danceability, energy, loudness        │
                         │ speechiness, acousticness             │
                         │ instrumentalness, liveness            │
                         │ valence, tempo                        │
                         │ tempo_bucket, energy_level            │
                         │ mood_score, organic_score             │
                         └───────────────────────────────────────┘
```

---

## Setup Instructions

### 1. Environment Variables
Create a `.env` file (never commit this):
```
DATABASE_URL=postgresql://user:password@host/dbname?sslmode=require
DBT_HOST=your-neon-host.neon.tech
DBT_USER=your_user
DBT_PASSWORD=your_password
DBT_DBNAME=your_dbname
```

### 2. Install dbt
```bash
pip install dbt-postgres
cd spotify_dbt
dbt deps          # install dbt-utils
dbt run           # build all models
dbt test          # run all data quality tests
dbt docs generate # build data catalog
dbt docs serve    # open catalog in browser
```

### 3. GitHub Actions Secrets
Add these in your repo → Settings → Secrets → Actions:
- `DBT_HOST`
- `DBT_USER`  
- `DBT_PASSWORD`
- `DBT_DBNAME`

### 4. Apply New Indexes
```bash
psql $DATABASE_URL -f indexes.sql
```

---

## Neon CU Monitoring
- SQLAlchemy uses `NullPool` — connections close immediately after use.
- Neon compute sleeps after 5 minutes of inactivity.
- Current usage: well within free tier (100 CU-hrs/month).

## Demo Video (Phase 1)
https://youtu.be/EeJOeXhqsHU