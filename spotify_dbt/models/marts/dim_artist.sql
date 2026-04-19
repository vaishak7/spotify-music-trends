-- models/marts/dim_artist.sql
-- EAS 550 | Vaishak Muralidharan
-- Star Schema Dimension: Artist
-- Enriched with aggregated track stats per artist

WITH artists AS (
    SELECT * FROM {{ ref('stg_artists') }}
),

track_artists AS (
    SELECT * FROM {{ source('spotify_oltp', 'track_artists') }}
),

tracks AS (
    SELECT * FROM {{ ref('stg_tracks') }}
),

artist_stats AS (
    SELECT
        ta.artist_id,
        count(DISTINCT ta.track_id) AS total_tracks,
        round(avg(t.popularity), 2) AS avg_popularity,
        max(t.popularity) AS peak_popularity,
        count(DISTINCT t.album_id) AS total_albums
    FROM track_artists AS ta
    INNER JOIN tracks AS t ON ta.track_id = t.track_id
    GROUP BY ta.artist_id
)

SELECT
    a.artist_id,
    a.artist_name,
    coalesce(s.total_tracks, 0) AS total_tracks,
    coalesce(s.avg_popularity, 0) AS avg_popularity,
    coalesce(s.peak_popularity, 0) AS peak_popularity,
    coalesce(s.total_albums, 0) AS total_albums
FROM artists AS a
LEFT JOIN artist_stats AS s ON a.artist_id = s.artist_id
