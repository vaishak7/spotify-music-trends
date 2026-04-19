WITH source AS (
    SELECT * FROM {{ source('spotify_oltp', 'albums') }}
)

SELECT
    album_id,
    trim(album_name) AS album_name
FROM source
WHERE album_name IS NOT null
