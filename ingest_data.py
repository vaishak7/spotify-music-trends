"""
ingest_data.py
==============
EAS 550 | Vaishak Muralidharan
Spotify Music Trends Analysis

Cleans and loads the Spotify Tracks dataset CSV into the
normalized PostgreSQL schema hosted on Neon.

Usage:
    python ingest_data.py

Environment variable required (set via GitHub Secrets or .env):
    DATABASE_URL  — e.g. postgresql://user:pass@host/dbname?sslmode=require

This script is fully IDEMPOTENT:
    - Uses ON CONFLICT DO NOTHING for all inserts, so running it
      multiple times will never duplicate or corrupt data.
    - Uses append mode for .to_sql with manual duplicate checking.
"""

import os
import sys
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.pool import NullPool

# =============================================================
# 1. DATABASE CONNECTION
# =============================================================

DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    sys.exit("ERROR: DATABASE_URL environment variable is not set.")

# NullPool is recommended for Neon serverless to avoid idle
# connections that prevent the compute from sleeping (which
# would drain your free-tier CU hours).
engine = create_engine(DATABASE_URL, poolclass=NullPool)
print("Connected to database.")


# =============================================================
# 2. LOAD & CLEAN RAW CSV
# =============================================================

CSV_PATH = "dataset.csv"

print(f"Loading {CSV_PATH}...")
df = pd.read_csv(CSV_PATH)

# Drop the unnamed index column the CSV carries
df.drop(columns=["Unnamed: 0"], errors="ignore", inplace=True)

# Drop the 3 rows with any null in critical text columns
df.dropna(subset=["track_id", "track_name", "artists", "album_name", "track_genre"], inplace=True)

# Ensure correct dtypes
df["popularity"]     = pd.to_numeric(df["popularity"],     errors="coerce").fillna(0).astype(int)
df["duration_ms"]    = pd.to_numeric(df["duration_ms"],    errors="coerce").fillna(0).astype(int)
df["explicit"]       = df["explicit"].astype(bool)
df["key"]            = pd.to_numeric(df["key"],            errors="coerce").fillna(0).astype(int)
df["mode"]           = pd.to_numeric(df["mode"],           errors="coerce").fillna(0).astype(int)
df["time_signature"] = pd.to_numeric(df["time_signature"], errors="coerce").fillna(4).astype(int)

# Clamp popularity to [0, 100] in case of dirty data
df["popularity"] = df["popularity"].clip(0, 100)

# Remove duplicate track_id rows (keep first occurrence)
df.drop_duplicates(subset=["track_id"], keep="first", inplace=True)

print(f"Cleaned dataset: {len(df)} rows.")


# =============================================================
# 3. INGEST — ORDER MATTERS (parent tables first)
# =============================================================

with engine.begin() as conn:

    # ----------------------------------------------------------
    # 3a. GENRES
    # ----------------------------------------------------------
    print("Inserting genres...")
    genres = df[["track_genre"]].drop_duplicates().rename(columns={"track_genre": "genre_name"})
    for _, row in genres.iterrows():
        conn.execute(
            text("INSERT INTO genres (genre_name) VALUES (:g) ON CONFLICT DO NOTHING"),
            {"g": row["genre_name"]}
        )

    # Build a genre_name -> genre_id lookup map
    genre_map = {r.genre_name: r.genre_id for r in conn.execute(text("SELECT genre_id, genre_name FROM genres"))}

    # ----------------------------------------------------------
    # 3b. ALBUMS
    # ----------------------------------------------------------
    print("Inserting albums...")
    albums = df[["album_name"]].drop_duplicates()
    for _, row in albums.iterrows():
        conn.execute(
            text("INSERT INTO albums (album_name) VALUES (:a) ON CONFLICT DO NOTHING"),
            {"a": row["album_name"]}
        )

    # Build album_name -> album_id lookup map
    album_map = {r.album_name: r.album_id for r in conn.execute(text("SELECT album_id, album_name FROM albums"))}

    # ----------------------------------------------------------
    # 3c. ARTISTS  (split semicolon-delimited artist strings)
    # ----------------------------------------------------------
    print("Inserting artists...")
    all_artists = set()
    for artist_str in df["artists"].dropna():
        for a in artist_str.split(";"):
            all_artists.add(a.strip())

    for artist in all_artists:
        conn.execute(
            text("INSERT INTO artists (artist_name) VALUES (:a) ON CONFLICT DO NOTHING"),
            {"a": artist}
        )

    # Build artist_name -> artist_id lookup map
    artist_map = {r.artist_name: r.artist_id for r in conn.execute(text("SELECT artist_id, artist_name FROM artists"))}

    # ----------------------------------------------------------
    # 3d. TRACKS
    # ----------------------------------------------------------
    print("Inserting tracks...")
    df["album_id"] = df["album_name"].map(album_map)
    df["genre_id"] = df["track_genre"].map(genre_map)

    tracks_df = df[["track_id", "track_name", "album_id", "genre_id",
                     "popularity", "duration_ms", "explicit",
                     "key", "mode", "time_signature"]].copy()

    for _, row in tracks_df.iterrows():
        conn.execute(text("""
            INSERT INTO tracks (track_id, track_name, album_id, genre_id,
                                popularity, duration_ms, explicit,
                                key, mode, time_signature)
            VALUES (:track_id, :track_name, :album_id, :genre_id,
                    :popularity, :duration_ms, :explicit,
                    :key, :mode, :time_signature)
            ON CONFLICT (track_id) DO NOTHING
        """), row.to_dict())

    # ----------------------------------------------------------
    # 3e. AUDIO_FEATURES
    # ----------------------------------------------------------
    print("Inserting audio features...")
    audio_cols = ["track_id", "danceability", "energy", "loudness",
                  "speechiness", "acousticness", "instrumentalness",
                  "liveness", "valence", "tempo"]
    audio_df = df[audio_cols].copy()

    for _, row in audio_df.iterrows():
        conn.execute(text("""
            INSERT INTO audio_features (track_id, danceability, energy, loudness,
                                        speechiness, acousticness, instrumentalness,
                                        liveness, valence, tempo)
            VALUES (:track_id, :danceability, :energy, :loudness,
                    :speechiness, :acousticness, :instrumentalness,
                    :liveness, :valence, :tempo)
            ON CONFLICT (track_id) DO NOTHING
        """), row.to_dict())

    # ----------------------------------------------------------
    # 3f. TRACK_ARTISTS  (bridge table — load last)
    # ----------------------------------------------------------
    print("Inserting track_artists bridge table...")
    for _, row in df[["track_id", "artists"]].iterrows():
        for artist_name in row["artists"].split(";"):
            a = artist_name.strip()
            aid = artist_map.get(a)
            if aid:
                conn.execute(text("""
                    INSERT INTO track_artists (track_id, artist_id)
                    VALUES (:t, :a)
                    ON CONFLICT DO NOTHING
                """), {"t": row["track_id"], "a": aid})

print("\nIngestion complete. All tables loaded successfully.")
