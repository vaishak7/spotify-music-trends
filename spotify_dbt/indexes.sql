-- -------------------------------------------------------------
-- EXISTING indexes (from Phase 1 schema.sql — already present)
-- -------------------------------------------------------------
-- idx_tracks_genre     ON tracks(genre_id)
-- idx_tracks_album     ON tracks(album_id)
-- idx_tracks_popularity ON tracks(popularity)
-- idx_track_artists_artist ON track_artists(artist_id)
 
-- -------------------------------------------------------------
-- NEW Phase 2 indexes — targeting the 3 advanced queries
-- -------------------------------------------------------------
 
-- Query 1 & 3 both JOIN tracks → audio_features and GROUP BY genre
-- Composite index on the two most-filtered audio columns
CREATE INDEX IF NOT EXISTS idx_audio_energy_valence
    ON audio_features (energy, valence);
 
-- Query 3 filters audio features and orders by popularity
-- Covering index for the mood cluster query's hot path
CREATE INDEX IF NOT EXISTS idx_audio_features_covering
    ON audio_features (track_id, energy, valence, danceability, tempo);
 
-- Query 2 & 3 join through track_artists → artists
-- Already have idx_track_artists_artist, add track_id side too
CREATE INDEX IF NOT EXISTS idx_track_artists_track
    ON track_artists (track_id);
 
-- Query 1: genre aggregation with popularity ordering
-- Composite covers the GROUP BY + ORDER BY without a sort step
CREATE INDEX IF NOT EXISTS idx_tracks_genre_popularity
    ON tracks (genre_id, popularity DESC);
 
-- Query 3: mood cluster needs genre join + audio join on same track
-- Partial index: only popular tracks (common dashboard filter)
CREATE INDEX IF NOT EXISTS idx_tracks_popular
    ON tracks (track_id, popularity, genre_id)
    WHERE popularity >= 50;
 
-- For dbt mart materialization: fact_tracks scans by genre
CREATE INDEX IF NOT EXISTS idx_tracks_explicit
    ON tracks (explicit)
    WHERE explicit = TRUE;
 
-- =============================================================
-- VERIFY indexes
-- =============================================================
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
 