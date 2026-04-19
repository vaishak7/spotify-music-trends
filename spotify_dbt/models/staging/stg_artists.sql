WITH source AS (
    SELECT * FROM {{ source('spotify_oltp', 'artists') }}
)

SELECT
    artist_id,
    trim(artist_name) AS artist_name
FROM source
WHERE artist_name IS NOT null
