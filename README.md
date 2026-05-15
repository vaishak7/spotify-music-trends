# Spotify Music Trends Analysis
**EAS 550 | Vaishak Muralidharan**

A full-stack data engineering project — from raw CSV ingestion to a live interactive dashboard. Built on Neon serverless PostgreSQL, transformed with dbt, tested with CI/CD, and deployed on Render.

🔗 **Live App:** https://spotify-music-trends.onrender.com

> Note: The app runs on Render's free tier and may take up to 60 seconds to wake up after inactivity. Just wait and it'll load.

---

## What This Project Does

Takes 114k Spotify tracks across 113 genres and turns them into an interactive analytics dashboard. You can explore genre popularity rankings, compare audio fingerprints across genres, track artist performance, and visualize mood clusters based on energy and valence.

All data is queried live from a PostgreSQL database — no static CSV files.

---

## Architecture

```
Raw CSV (114k rows)
      │
      ▼
ingest_data.py  ──►  Neon PostgreSQL (OLTP)
                            │
                            ▼
                     dbt Transformations
                     ├── Staging views (stg_*)
                     └── Star Schema marts
                          ├── fact_tracks
                          ├── dim_genre
                          ├── dim_album
                          └── dim_artist
                            │
                            ▼
                    Streamlit Dashboard
                    (deployed on Render)
```

---

## Live Dashboard Features

| Page | What it shows |
|------|--------------|
| Overview | Key stats + top genres bar chart |
| Genre Analysis | Popularity scatter, distribution histogram, data table |
| Audio Features | Radar chart + heatmap comparing genres side by side |
| Artist Performance | Top artists bar chart + energy vs popularity bubble chart |
| Mood Clusters | Mood pie chart, top genres per mood, mood × genre heatmap |

---

## Project Structure

```
spotify-music-trends/
├── app.py                    # Streamlit dashboard (Phase 3)
├── db.py                     # DB connection pool
├── requirements.txt          # Python dependencies
├── render.yaml               # Render deployment config
├── runtime.txt               # Python version pin
├── schema.sql                # OLTP schema
├── ingest_data.py            # Data ingestion pipeline
├── security.sql              # RBAC roles
├── ERD_Spotify.png           # Entity relationship diagram
├── star_schema_diagram.png   # dbt lineage graph
├── indexes.sql               # Performance indexes
├── performance_tuning_report.md
├── 3NF_justification_report.md
├── spotify_dbt/
│   ├── dbt_project.yml
│   ├── packages.yml
│   ├── profiles.yml
│   ├── .sqlfluff
│   ├── models/
│   │   ├── staging/
│   │   │   ├── sources.yml
│   │   │   ├── stg_tracks.sql
│   │   │   ├── stg_audio_features.sql
│   │   │   ├── stg_artists.sql
│   │   │   ├── stg_albums.sql
│   │   │   └── stg_genres.sql
│   │   └── marts/
│   │       ├── schema.yml
│   │       ├── fact_tracks.sql
│   │       ├── dim_artist.sql
│   │       ├── dim_genre.sql
│   │       └── dim_album.sql
│   ├── tests/
│   │   ├── assert_no_orphaned_audio_features.sql
│   │   ├── assert_popularity_range.sql
│   │   └── assert_every_track_has_artist.sql
│   ├── advanced_query_1_genre_ranking.sql
│   ├── advanced_query_2_artist_performance_tiers.sql
│   └── advanced_query_3_mood_clusters.sql
└── .github/
    └── workflows/
        └── ci.yml            # GitHub Actions CI/CD
```

---

## Star Schema

```
                    ┌─────────────┐
                    │  dim_genre  │
                    └──────┬──────┘
                           │
┌─────────────┐    ┌───────▼──────────┐    ┌──────────────┐
│  dim_album  │◄───│   fact_tracks    │───►│  dim_artist  │
└─────────────┘    │  (89,740 rows)   │    └──────────────┘
                   │                  │
                   │ track_id PK      │
                   │ popularity       │
                   │ danceability     │
                   │ energy, valence  │
                   │ tempo, loudness  │
                   │ mood_score       │
                   └──────────────────┘
```

---

## Setup & Running Locally

### 1. Clone and create `.env`
```bash
git clone https://github.com/vaishak7/spotify-music-trends
cd spotify-music-trends
```

Create a `.env` file (never commit this):
```
DATABASE_URL=postgresql://user:password@host/dbname?sslmode=require
DBT_HOST=your-neon-host.neon.tech
DBT_USER=your_user
DBT_PASSWORD=your_password
DBT_DBNAME=your_dbname
```

### 2. Run the dashboard locally
```bash
pip install -r requirements.txt
streamlit run app.py
```

### 3. Run dbt transformations
```bash
pip install dbt-postgres
cd spotify_dbt
dbt deps
dbt run
dbt test
dbt docs generate && dbt docs serve
```

### 4. GitHub Actions secrets
Add these in repo → Settings → Secrets → Actions:
- `DBT_HOST`, `DBT_USER`, `DBT_PASSWORD`, `DBT_DBNAME`

---

## Data Quality — dbt Tests

56 tests run automatically on every push via GitHub Actions:
- `not_null` and `unique` on every primary key
- `relationships` (referential integrity) across all tables
- `accepted_values` on derived columns (energy_level, tempo_bucket)
- `accepted_range` on numeric columns (popularity 0–100, audio features 0–1)
- 3 custom singular tests for data integrity

---

## Performance

Query 3 (mood cluster analysis) processes 89,740 rows via a 3-table JOIN:
- Execution time: **94.8ms**
- Buffer hits: **2,196 (all from shared cache — zero disk reads)**
- 6 strategic indexes added including a covering index on `audio_features`

---

## Neon Database

- Hosted on Neon serverless PostgreSQL (AWS US East 1)
- Uses `NullPool` so connections close immediately after use
- Neon compute sleeps after 5 minutes of inactivity
- Well within free tier (100 CU-hrs/month)

---

## Demo Videos

- Phase 1: https://youtu.be/EeJOeXhqsHU
- Phase 3: https://youtu.be/9ygB4chkJNM
