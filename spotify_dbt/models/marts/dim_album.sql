-- models/marts/dim_album.sql
-- EAS 550 | Vaishak Muralidharan
-- Star Schema Dimension: Album

WITH albums AS (
    SELECT * FROM {{ ref('stg_albums') }}
),

tracks AS (
    SELECT * FROM {{ ref('stg_tracks') }}
),

album_stats AS (
    SELECT
        album_id,
        count(*) AS total_tracks,
        round(avg(popularity), 2) AS avg_popularity,
        sum(duration_ms) AS total_duration_ms
    FROM tracks
    GROUP BY album_id
)

SELECT
    a.album_id,
    a.album_name,
    coalesce(s.total_tracks, 0) AS total_tracks,
    coalesce(s.avg_popularity, 0) AS avg_popularity,
    coalesce(s.total_duration_ms, 0) AS total_duration_ms
FROM albums AS a
LEFT JOIN album_stats AS s ON a.album_id = s.album_id
