with source as (
    select * from {{ source('spotify_oltp', 'genres') }}
)

select
    genre_id,
    trim(lower(genre_name)) as genre_name
from source
where genre_name is not null