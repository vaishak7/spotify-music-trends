WITH genre_stats AS (
    -- Step 1: Aggregate raw metrics per genre
    SELECT
        g.genre_name,
        COUNT(t.track_id)                        AS total_tracks,
        ROUND(AVG(t.popularity)::NUMERIC, 2)     AS avg_popularity,
        ROUND(STDDEV(t.popularity)::NUMERIC, 2)  AS stddev_popularity,
        ROUND(AVG(af.danceability)::NUMERIC, 4)  AS avg_danceability,
        ROUND(AVG(af.energy)::NUMERIC, 4)        AS avg_energy,
        ROUND(AVG(af.valence)::NUMERIC, 4)       AS avg_valence,
        ROUND(AVG(af.tempo)::NUMERIC, 2)         AS avg_tempo
    FROM genres g
    JOIN tracks t        ON g.genre_id = t.genre_id
    JOIN audio_features af ON t.track_id = af.track_id
    GROUP BY g.genre_name
    HAVING COUNT(t.track_id) >= 10  -- exclude micro-genres
),
 
ranked_genres AS (
    -- Step 2: Apply window functions for ranking and percentiles
    SELECT
        genre_name,
        total_tracks,
        avg_popularity,
        stddev_popularity,
        avg_danceability,
        avg_energy,
        avg_valence,
        avg_tempo,
 
        -- Rank by popularity (1 = most popular)
        RANK() OVER (ORDER BY avg_popularity DESC)                   AS popularity_rank,
 
        -- Percentile position (1.0 = top, 0.0 = bottom)
        ROUND(PERCENT_RANK() OVER (
            ORDER BY avg_popularity
        )::NUMERIC, 4)                                               AS popularity_percentile,
 
        -- Running total of tracks (ordered by popularity rank)
        SUM(total_tracks) OVER (
            ORDER BY avg_popularity DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                            AS cumulative_tracks,
 
        -- Genre's share of total catalog
        ROUND(
            total_tracks * 100.0 / SUM(total_tracks) OVER ()
        , 2)                                                         AS pct_of_catalog
 
    FROM genre_stats
)
 
SELECT
    popularity_rank,
    genre_name,
    total_tracks,
    pct_of_catalog,
    avg_popularity,
    stddev_popularity,
    avg_danceability,
    avg_energy,
    avg_valence,
    avg_tempo,
    popularity_percentile,
    cumulative_tracks
FROM ranked_genres
ORDER BY popularity_rank
LIMIT 20;
 