WITH source AS (
    SELECT * FROM {{ source('spotify_oltp', 'genres') }}
)

SELECT
    genre_id,
    trim(lower(genre_name)) AS genre_name
FROM source
WHERE genre_name IS NOT null
