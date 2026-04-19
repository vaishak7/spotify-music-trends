-- models/marts/fact_tracks.sql
-- EAS 550 | Vaishak Muralidharan
-- Star Schema FACT TABLE: fact_tracks
-- Central fact table joining all dimensions.
-- Grain: one row per track.

WITH tracks AS (
    SELECT * FROM {{ ref('stg_tracks') }}
),

audio AS (
    SELECT * FROM {{ ref('stg_audio_features') }}
),

-- Aggregate artist names per track for denormalization
track_artists AS (
    SELECT * FROM {{ source('spotify_oltp', 'track_artists') }}
),

artists AS (
    SELECT * FROM {{ ref('stg_artists') }}
),

artist_agg AS (
    SELECT
        ta.track_id,
        string_agg(a.artist_name, '; ' ORDER BY a.artist_name) AS artist_names,
        count(*) AS artist_count
    FROM track_artists AS ta
    INNER JOIN artists AS a ON ta.artist_id = a.artist_id
    GROUP BY ta.track_id
)

SELECT
    -- Keys
    t.track_id,
    t.album_id,
    t.genre_id,

    -- Track attributes
    t.track_name,
    t.popularity,
    t.duration_ms,
    t.duration_seconds,
    t.explicit,
    t.key,
    t.mode,
    t.time_signature,

    -- Artist info (denormalized for convenience)
    aa.artist_names,
    aa.artist_count,

    -- Audio features
    af.danceability,
    af.energy,
    af.loudness,
    af.speechiness,
    af.acousticness,
    af.instrumentalness,
    af.liveness,
    af.valence,
    af.tempo,
    af.tempo_bucket,
    af.energy_level,

    -- Derived metrics
    round((af.danceability + af.energy + af.valence) / 3.0, 4) AS mood_score,
    round((af.acousticness + af.instrumentalness) / 2.0, 4) AS organic_score

FROM tracks AS t
LEFT JOIN audio AS af ON t.track_id = af.track_id
LEFT JOIN artist_agg AS aa ON t.track_id = aa.track_id
