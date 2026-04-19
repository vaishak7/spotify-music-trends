-- models/marts/dim_genre.sql
-- EAS 550 | Vaishak Muralidharan
-- Star Schema Dimension: Genre

WITH genres AS (
    SELECT * FROM {{ ref('stg_genres') }}
),

tracks AS (
    SELECT * FROM {{ ref('stg_tracks') }}
),

genre_stats AS (
    SELECT
        genre_id,
        count(*) AS total_tracks,
        round(avg(popularity), 2) AS avg_popularity,
        sum(CASE WHEN explicit THEN 1 ELSE 0 END) AS explicit_tracks
    FROM tracks
    GROUP BY genre_id
)

SELECT
    g.genre_id,
    g.genre_name,
    coalesce(s.total_tracks, 0) AS total_tracks,
    coalesce(s.avg_popularity, 0) AS avg_popularity,
    coalesce(s.explicit_tracks, 0) AS explicit_tracks
FROM genres AS g
LEFT JOIN genre_stats AS s ON g.genre_id = s.genre_id
