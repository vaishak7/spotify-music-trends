WITH source AS (
    SELECT * FROM {{ source('spotify_oltp', 'tracks') }}
),

renamed AS (
    SELECT
        track_id,
        track_name,
        album_id,
        genre_id,
        popularity,
        duration_ms,
        explicit,
        key,
        mode,
        time_signature,
        round(duration_ms / 1000.0, 2) AS duration_seconds
    FROM source
    WHERE
        track_id IS NOT null
        AND track_name IS NOT null
        AND popularity BETWEEN 0 AND 100
        AND duration_ms > 0
)

SELECT * FROM renamed
