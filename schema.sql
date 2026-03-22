-- =============================================================
-- Spotify Music Trends Analysis - Database Schema
-- EAS 550 | Vaishak Muralidharan
-- =============================================================
-- Run this script once against your Neon PostgreSQL instance.
-- All tables are created only if they don't already exist,
-- making this script safe to re-run (idempotent).
-- =============================================================


-- -------------------------------------------------------------
-- 1. GENRES
-- Lookup table for the 114 unique track genres.
-- Extracted from the flat CSV to avoid repeating genre strings
-- in every track row (1NF -> 3NF).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS genres (
    genre_id   SERIAL      PRIMARY KEY,
    genre_name TEXT        NOT NULL UNIQUE
);


-- -------------------------------------------------------------
-- 2. ARTISTS
-- One row per unique artist name.
-- Because the CSV stores multiple artists as a semicolon-
-- delimited string (e.g. "Ingrid Michaelson;ZAYN"), we resolve
-- the many-to-many relationship via the track_artists bridge
-- table below.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS artists (
    artist_id   SERIAL  PRIMARY KEY,
    artist_name TEXT    NOT NULL UNIQUE
);


-- -------------------------------------------------------------
-- 3. ALBUMS
-- One row per unique album name.
-- NOTE: The source dataset has no album_id; we generate one
-- here. Album name alone is used as the natural key during
-- ingestion (ON CONFLICT DO NOTHING).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS albums (
    album_id   SERIAL  PRIMARY KEY,
    album_name TEXT    NOT NULL
);


-- -------------------------------------------------------------
-- 4. TRACKS (core fact table)
-- Holds identity and categorical attributes of each track.
-- Audio features are separated into their own table (see below)
-- to keep this table focused on "what the track is" rather than
-- "how it sounds".
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tracks (
    track_id       TEXT    PRIMARY KEY,           -- Spotify's own ID (e.g. "5SuOikwiRyPMVoIQDJUgSV")
    track_name     TEXT    NOT NULL,
    album_id       INT     REFERENCES albums(album_id)  ON DELETE SET NULL,
    genre_id       INT     REFERENCES genres(genre_id)  ON DELETE SET NULL,
    popularity     SMALLINT NOT NULL CHECK (popularity BETWEEN 0 AND 100),
    duration_ms    INT     NOT NULL CHECK (duration_ms > 0),
    explicit       BOOLEAN NOT NULL DEFAULT FALSE,
    key            SMALLINT CHECK (key BETWEEN 0 AND 11),   -- Pitch class notation: 0=C, 1=C#, ...
    mode           SMALLINT CHECK (mode IN (0, 1)),          -- 0 = minor, 1 = major
    time_signature SMALLINT CHECK (time_signature BETWEEN 1 AND 7)
);


-- -------------------------------------------------------------
-- 5. AUDIO_FEATURES
-- All continuous audio measurements live here, linked 1-to-1
-- with tracks. Separating them keeps tracks lean and lets us
-- query acoustic properties independently.
-- All Spotify audio features are normalised to [0.0, 1.0]
-- except loudness (dB, typically -60 to 0) and tempo (BPM).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audio_features (
    track_id         TEXT        PRIMARY KEY REFERENCES tracks(track_id) ON DELETE CASCADE,
    danceability     DECIMAL(5,4) NOT NULL CHECK (danceability     BETWEEN 0 AND 1),
    energy           DECIMAL(5,4) NOT NULL CHECK (energy           BETWEEN 0 AND 1),
    loudness         DECIMAL(6,3) NOT NULL CHECK (loudness         BETWEEN -60 AND 5),
    speechiness      DECIMAL(5,4) NOT NULL CHECK (speechiness      BETWEEN 0 AND 1),
    acousticness     DECIMAL(5,4) NOT NULL CHECK (acousticness     BETWEEN 0 AND 1),
    instrumentalness DECIMAL(5,4) NOT NULL CHECK (instrumentalness BETWEEN 0 AND 1),
    liveness         DECIMAL(5,4) NOT NULL CHECK (liveness         BETWEEN 0 AND 1),
    valence          DECIMAL(5,4) NOT NULL CHECK (valence          BETWEEN 0 AND 1),
    tempo            DECIMAL(6,3) NOT NULL CHECK (tempo            > 0)
);


-- -------------------------------------------------------------
-- 6. TRACK_ARTISTS  (bridge / junction table)
-- Resolves the many-to-many relationship between tracks and
-- artists. One track can have multiple artists; one artist can
-- appear on many tracks.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS track_artists (
    track_id  TEXT  NOT NULL REFERENCES tracks(track_id)   ON DELETE CASCADE,
    artist_id INT   NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE,
    PRIMARY KEY (track_id, artist_id)   -- composite PK prevents duplicate entries
);


-- =============================================================
-- Indexes for common dashboard query patterns
-- =============================================================

-- Filter / group tracks by genre or album
CREATE INDEX IF NOT EXISTS idx_tracks_genre  ON tracks(genre_id);
CREATE INDEX IF NOT EXISTS idx_tracks_album  ON tracks(album_id);

-- Sort / filter by popularity
CREATE INDEX IF NOT EXISTS idx_tracks_popularity ON tracks(popularity);

-- Join from bridge table to artists
CREATE INDEX IF NOT EXISTS idx_track_artists_artist ON track_artists(artist_id);
