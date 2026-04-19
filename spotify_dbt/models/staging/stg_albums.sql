with source as (
    select * from {{ source('spotify_oltp', 'albums') }}
)

select
    album_id,
    trim(album_name) as album_name
from source
where album_name is not null