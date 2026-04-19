WITH source AS (
    SELECT * FROM {{ source('spotify_oltp', 'audio_features') }}
),

cleaned AS (
    SELECT
        track_id,
        danceability,
        energy,
        loudness,
        speechiness,
        acousticness,
        instrumentalness,
        liveness,
        valence,
        tempo,
        CASE
            WHEN tempo < 80 THEN 'slow'
            WHEN tempo < 120 THEN 'medium'
            ELSE 'fast'
        END AS tempo_bucket,
        CASE
            WHEN energy >= 0.75 THEN 'high'
            WHEN energy >= 0.40 THEN 'medium'
            ELSE 'low'
        END AS energy_level
    FROM source
    WHERE
        track_id IS NOT null
        AND danceability BETWEEN 0 AND 1
        AND energy BETWEEN 0 AND 1
        AND loudness BETWEEN -60 AND 5
        AND tempo > 0
)

SELECT * FROM cleaned
