WITH artist_track_stats AS (
    -- Step 1: Per-artist aggregated track + audio metrics
    SELECT
        a.artist_id,
        a.artist_name,
        COUNT(DISTINCT ta.track_id)               AS track_count,
        COUNT(DISTINCT t.album_id)                AS album_count,
        ROUND(AVG(t.popularity)::NUMERIC, 2)      AS avg_popularity,
        MAX(t.popularity)                         AS peak_popularity,
        ROUND(AVG(af.danceability)::NUMERIC, 4)   AS avg_danceability,
        ROUND(AVG(af.energy)::NUMERIC, 4)         AS avg_energy,
        ROUND(AVG(af.valence)::NUMERIC, 4)        AS avg_valence,
        ROUND(AVG(af.acousticness)::NUMERIC, 4)   AS avg_acousticness,
        ROUND(AVG(af.instrumentalness)::NUMERIC, 4) AS avg_instrumentalness,
        ROUND(AVG(af.tempo)::NUMERIC, 2)          AS avg_tempo,
        SUM(CASE WHEN t.explicit THEN 1 ELSE 0 END) AS explicit_track_count
    FROM artists a
    JOIN track_artists ta  ON a.artist_id = ta.artist_id
    JOIN tracks t          ON ta.track_id = t.track_id
    JOIN audio_features af ON t.track_id = af.track_id
    GROUP BY a.artist_id, a.artist_name
    HAVING COUNT(DISTINCT ta.track_id) >= 3  -- minimum catalog size
),
 
tiered_artists AS (
    -- Step 2: Assign performance tiers using NTILE
    SELECT
        *,
        NTILE(4) OVER (ORDER BY avg_popularity DESC) AS popularity_quartile,
 
        -- Lag to compare each artist with the one ranked just above
        LAG(avg_popularity) OVER (
            ORDER BY avg_popularity DESC
        )                                            AS prev_artist_popularity,
 
        -- Composite "vibe score" combining danceability + energy + valence
        ROUND((avg_danceability + avg_energy + avg_valence) / 3.0, 4) AS vibe_score
    FROM artist_track_stats
),
 
tier_benchmarks AS (
    -- Step 3: Compute average popularity per tier for comparison
    SELECT
        popularity_quartile,
        ROUND(AVG(avg_popularity)::NUMERIC, 2) AS tier_avg_popularity,
        ROUND(AVG(vibe_score)::NUMERIC, 4)     AS tier_avg_vibe
    FROM tiered_artists
    GROUP BY popularity_quartile
)
 
SELECT
    ta.artist_name,
    ta.track_count,
    ta.album_count,
    ta.avg_popularity,
    ta.peak_popularity,
    ta.vibe_score,
    ta.avg_tempo,
    ta.explicit_track_count,
 
    -- Tier label
    CASE ta.popularity_quartile
        WHEN 1 THEN 'Platinum'
        WHEN 2 THEN 'Gold'
        WHEN 3 THEN 'Silver'
        WHEN 4 THEN 'Emerging'
    END                                              AS performance_tier,
 
    tb.tier_avg_popularity,
 
    -- Is this artist above their tier average?
    CASE
        WHEN ta.avg_popularity > tb.tier_avg_popularity THEN 'Above Average'
        ELSE 'Below Average'
    END                                              AS tier_standing,
 
    -- How much they differ from the tier avg
    ROUND((ta.avg_popularity - tb.tier_avg_popularity)::NUMERIC, 2) AS popularity_vs_tier,
 
    -- Gap to next artist above (popularity loss going down the list)
    ROUND((ta.prev_artist_popularity - ta.avg_popularity)::NUMERIC, 2) AS gap_to_artist_above
 
FROM tiered_artists ta
JOIN tier_benchmarks tb ON ta.popularity_quartile = tb.popularity_quartile
ORDER BY ta.avg_popularity DESC
LIMIT 30;
 