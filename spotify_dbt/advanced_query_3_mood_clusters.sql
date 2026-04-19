WITH track_mood AS (
    -- Step 1: Assign each track a mood quadrant based on energy + valence
    SELECT
        t.track_id,
        t.track_name,
        t.popularity,
        g.genre_name,
        af.energy,
        af.valence,
        af.danceability,
        af.acousticness,
        af.tempo,
 
        -- Mood quadrant (Russell's circumplex model approximation)
        CASE
            WHEN af.valence >= 0.5 AND af.energy >= 0.5 THEN 'Happy / Energetic'
            WHEN af.valence >= 0.5 AND af.energy <  0.5 THEN 'Peaceful / Content'
            WHEN af.valence <  0.5 AND af.energy >= 0.5 THEN 'Angry / Intense'
            ELSE                                              'Sad / Melancholic'
        END AS mood_quadrant,
 
        -- Popularity tier within the full dataset
        NTILE(5) OVER (ORDER BY t.popularity DESC) AS global_popularity_quintile
 
    FROM tracks t
    JOIN audio_features af ON t.track_id = af.track_id
    JOIN genres g          ON t.genre_id  = g.genre_id
),
 
genre_mood_counts AS (
    -- Step 2: Count how many tracks per genre fall into each mood
    SELECT
        genre_name,
        mood_quadrant,
        COUNT(*)                             AS track_count,
        ROUND(AVG(popularity)::NUMERIC, 2)   AS avg_popularity,
        ROUND(AVG(danceability)::NUMERIC, 4) AS avg_danceability,
        ROUND(AVG(tempo)::NUMERIC, 2)        AS avg_tempo,
 
        -- Tracks in top popularity quintile (global stars)
        COUNT(*) FILTER (WHERE global_popularity_quintile = 1) AS top_quintile_tracks
    FROM track_mood
    GROUP BY genre_name, mood_quadrant
),
 
genre_totals AS (
    -- Step 3: Total tracks per genre (for % calculation)
    SELECT genre_name, SUM(track_count) AS genre_total
    FROM genre_mood_counts
    GROUP BY genre_name
),
 
genre_mood_ranked AS (
    -- Step 4: Rank moods within each genre + compute pct share
    SELECT
        gmc.genre_name,
        gmc.mood_quadrant,
        gmc.track_count,
        gmc.avg_popularity,
        gmc.avg_danceability,
        gmc.avg_tempo,
        gmc.top_quintile_tracks,
 
        -- Pct of this genre's catalog in this mood
        ROUND(gmc.track_count * 100.0 / gt.genre_total, 2) AS pct_of_genre,
 
        -- Rank moods within each genre (1 = dominant mood)
        ROW_NUMBER() OVER (
            PARTITION BY gmc.genre_name
            ORDER BY gmc.track_count DESC
        )                                                   AS mood_rank_in_genre,
 
        -- Running total within genre (ordered by mood prevalence)
        SUM(gmc.track_count) OVER (
            PARTITION BY gmc.genre_name
            ORDER BY gmc.track_count DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                   AS cumulative_tracks_in_genre,
 
        -- Avg popularity of this mood across ALL genres (global benchmark)
        ROUND(AVG(gmc.avg_popularity) OVER (
            PARTITION BY gmc.mood_quadrant
        )::NUMERIC, 2)                                      AS global_mood_avg_popularity
 
    FROM genre_mood_counts gmc
    JOIN genre_totals gt ON gmc.genre_name = gt.genre_name
)
 
SELECT
    genre_name,
    mood_quadrant,
    track_count,
    pct_of_genre,
    avg_popularity,
    global_mood_avg_popularity,
 
    -- Is this genre above global mood average?
    CASE
        WHEN avg_popularity > global_mood_avg_popularity THEN '▲ Above Global'
        ELSE '▼ Below Global'
    END                                    AS vs_global_mood_avg,
 
    avg_danceability,
    avg_tempo,
    top_quintile_tracks,
    mood_rank_in_genre,
    cumulative_tracks_in_genre
 
FROM genre_mood_ranked
WHERE mood_rank_in_genre <= 4           -- top 4 moods per genre
  AND track_count >= 5                  -- exclude noise
ORDER BY genre_name, mood_rank_in_genre;
 