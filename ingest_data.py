"""
ingest_data.py
==============
EAS 550 | Vaishak Muralidharan
Spotify Music Trends Analysis

Uses COPY (fastest PostgreSQL bulk load method) via psycopg2
to load all 114k rows as fast as possible without timeouts.
Fully IDEMPOTENT — safe to run multiple times.
"""

import os
import sys
import io
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.pool import NullPool
import psycopg2

load_dotenv()

# =============================================================
# 1. DATABASE CONNECTION
# =============================================================

DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    sys.exit("ERROR: DATABASE_URL environment variable is not set.")

engine = create_engine(DATABASE_URL, poolclass=NullPool)
print("Connected to database.")

# Raw psycopg2 connection for COPY commands
raw_conn = psycopg2.connect(DATABASE_URL)
raw_conn.autocommit = False
cur = raw_conn.cursor()

# =============================================================
# 2. LOAD & CLEAN RAW CSV
# =============================================================

print("Loading dataset.csv...")
df = pd.read_csv("dataset.csv")

df.drop(columns=["Unnamed: 0"], errors="ignore", inplace=True)
df.dropna(subset=["track_id", "track_name", "artists", "album_name", "track_genre"], inplace=True)

df["popularity"]     = pd.to_numeric(df["popularity"],     errors="coerce").fillna(0).astype(int)
df["duration_ms"]    = pd.to_numeric(df["duration_ms"],    errors="coerce").fillna(0).astype(int)
df["explicit"]       = df["explicit"].astype(bool)
df["key"]            = pd.to_numeric(df["key"],            errors="coerce").fillna(0).astype(int)
df["mode"]           = pd.to_numeric(df["mode"],           errors="coerce").fillna(0).astype(int)
df["time_signature"] = pd.to_numeric(df["time_signature"], errors="coerce").fillna(4).astype(int)
df["time_signature"] = df["time_signature"].replace(0, 4)
df["tempo"]          = pd.to_numeric(df["tempo"], errors="coerce").fillna(60.0)
df["tempo"]          = df["tempo"].apply(lambda x: 60.0 if x <= 0 else x)
df["popularity"]     = df["popularity"].clip(0, 100)
df.drop_duplicates(subset=["track_id"], keep="first", inplace=True)

print(f"Cleaned dataset: {len(df)} rows.")


# =============================================================
# 3. HELPER: fast COPY insert into a temp table then upsert
# =============================================================

def copy_insert(cur, df_chunk, temp_table, final_table, columns, insert_sql):
    """
    Fastest bulk load method:
    1. COPY data into a temp table (no constraints)
    2. INSERT from temp into real table with ON CONFLICT DO NOTHING
    """
    col_list = ", ".join(columns)
    cur.execute(f"CREATE TEMP TABLE {temp_table} (LIKE {final_table} INCLUDING DEFAULTS) ON COMMIT DROP")
    
    buf = io.StringIO()
    df_chunk[columns].to_csv(buf, index=False, header=False, sep="\t", na_rep="\\N")
    buf.seek(0)
    cur.copy_from(buf, temp_table, sep="\t", null="\\N", columns=columns)
    
    cur.execute(insert_sql)
    cur.execute(f"DROP TABLE IF EXISTS {temp_table}")


# =============================================================
# 4. INGEST
# =============================================================

# ----------------------------------------------------------
# 4a. GENRES
# ----------------------------------------------------------
print("Inserting genres...")
genres_df = pd.DataFrame(df["track_genre"].unique(), columns=["genre_name"])
buf = io.StringIO()
genres_df.to_csv(buf, index=False, header=False)
buf.seek(0)
cur.execute("CREATE TEMP TABLE tmp_genres (genre_name TEXT) ON COMMIT DROP")
cur.copy_from(buf, "tmp_genres", columns=["genre_name"])
cur.execute("INSERT INTO genres (genre_name) SELECT genre_name FROM tmp_genres ON CONFLICT DO NOTHING")
raw_conn.commit()

cur.execute("SELECT genre_id, genre_name FROM genres")
genre_map = {r[1]: r[0] for r in cur.fetchall()}
print(f"  {len(genre_map)} genres loaded.")

# ----------------------------------------------------------
# 4b. ALBUMS
# ----------------------------------------------------------
print("Inserting albums...")
albums_df = pd.DataFrame(df["album_name"].unique(), columns=["album_name"])
buf = io.StringIO()
albums_df.to_csv(buf, index=False, header=False, quoting=1)
buf.seek(0)
cur.execute("CREATE TEMP TABLE tmp_albums (album_name TEXT) ON COMMIT DROP")
cur.copy_expert("COPY tmp_albums (album_name) FROM STDIN WITH CSV", buf)
cur.execute("INSERT INTO albums (album_name) SELECT album_name FROM tmp_albums ON CONFLICT DO NOTHING")
raw_conn.commit()

cur.execute("SELECT album_id, album_name FROM albums")
album_map = {r[1]: r[0] for r in cur.fetchall()}
print(f"  {len(album_map)} albums loaded.")

# ----------------------------------------------------------
# 4c. ARTISTS
# ----------------------------------------------------------
print("Inserting artists...")
all_artists = set()
for artist_str in df["artists"].dropna():
    for a in artist_str.split(";"):
        all_artists.add(a.strip())

artists_df = pd.DataFrame(list(all_artists), columns=["artist_name"])
buf = io.StringIO()
artists_df.to_csv(buf, index=False, header=False, quoting=1)
buf.seek(0)
cur.execute("CREATE TEMP TABLE tmp_artists (artist_name TEXT) ON COMMIT DROP")
cur.copy_expert("COPY tmp_artists (artist_name) FROM STDIN WITH CSV", buf)
cur.execute("INSERT INTO artists (artist_name) SELECT artist_name FROM tmp_artists ON CONFLICT DO NOTHING")
raw_conn.commit()

cur.execute("SELECT artist_id, artist_name FROM artists")
artist_map = {r[1]: r[0] for r in cur.fetchall()}
print(f"  {len(artist_map)} artists loaded.")

# ----------------------------------------------------------
# 4d. TRACKS
# ----------------------------------------------------------
print("Inserting tracks...")
df["album_id"] = df["album_name"].map(album_map)
df["genre_id"] = df["track_genre"].map(genre_map)

tracks_df = df[["track_id", "track_name", "album_id", "genre_id",
                 "popularity", "duration_ms", "explicit",
                 "key", "mode", "time_signature"]].copy()

buf = io.StringIO()
tracks_df.to_csv(buf, index=False, header=False, quoting=1)
buf.seek(0)
cur.execute("""
    CREATE TEMP TABLE tmp_tracks (
        track_id TEXT, track_name TEXT, album_id INT, genre_id INT,
        popularity INT, duration_ms INT, explicit BOOLEAN,
        key INT, mode INT, time_signature INT
    ) ON COMMIT DROP
""")
cur.copy_expert("COPY tmp_tracks FROM STDIN WITH CSV", buf)
cur.execute("""
    INSERT INTO tracks (track_id, track_name, album_id, genre_id,
                        popularity, duration_ms, explicit, key, mode, time_signature)
    SELECT track_id, track_name, album_id, genre_id,
           popularity, duration_ms, explicit, key, mode, time_signature
    FROM tmp_tracks
    ON CONFLICT (track_id) DO NOTHING
""")
raw_conn.commit()
print(f"  {len(tracks_df)} tracks loaded.")

# ----------------------------------------------------------
# 4e. AUDIO FEATURES
# ----------------------------------------------------------
print("Inserting audio features...")
audio_df = df[["track_id", "danceability", "energy", "loudness",
               "speechiness", "acousticness", "instrumentalness",
               "liveness", "valence", "tempo"]].copy()

buf = io.StringIO()
audio_df.to_csv(buf, index=False, header=False, quoting=1)
buf.seek(0)
cur.execute("""
    CREATE TEMP TABLE tmp_audio (
        track_id TEXT, danceability DECIMAL, energy DECIMAL, loudness DECIMAL,
        speechiness DECIMAL, acousticness DECIMAL, instrumentalness DECIMAL,
        liveness DECIMAL, valence DECIMAL, tempo DECIMAL
    ) ON COMMIT DROP
""")
cur.copy_expert("COPY tmp_audio FROM STDIN WITH CSV", buf)
cur.execute("""
    INSERT INTO audio_features (track_id, danceability, energy, loudness,
                                speechiness, acousticness, instrumentalness,
                                liveness, valence, tempo)
    SELECT track_id, danceability, energy, loudness,
           speechiness, acousticness, instrumentalness,
           liveness, valence, tempo
    FROM tmp_audio
    ON CONFLICT (track_id) DO NOTHING
""")
raw_conn.commit()
print(f"  {len(audio_df)} audio feature rows loaded.")

# ----------------------------------------------------------
# 4f. TRACK_ARTISTS (bridge table)
# ----------------------------------------------------------
print("Inserting track_artists...")
bridge_records = []
for _, row in df[["track_id", "artists"]].iterrows():
    for artist_name in row["artists"].split(";"):
        a = artist_name.strip()
        aid = artist_map.get(a)
        if aid:
            bridge_records.append((row["track_id"], aid))

bridge_df = pd.DataFrame(bridge_records, columns=["track_id", "artist_id"])
bridge_df.drop_duplicates(inplace=True)

buf = io.StringIO()
bridge_df.to_csv(buf, index=False, header=False, quoting=1)
buf.seek(0)
cur.execute("CREATE TEMP TABLE tmp_bridge (track_id TEXT, artist_id INT) ON COMMIT DROP")
cur.copy_expert("COPY tmp_bridge FROM STDIN WITH CSV", buf)
cur.execute("""
    INSERT INTO track_artists (track_id, artist_id)
    SELECT track_id, artist_id FROM tmp_bridge
    ON CONFLICT DO NOTHING
""")
raw_conn.commit()
print(f"  {len(bridge_df)} track-artist links loaded.")

cur.close()
raw_conn.close()
print("\nIngestion complete. All tables loaded successfully.")