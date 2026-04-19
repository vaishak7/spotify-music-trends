select track_id, popularity
from {{ source('spotify_oltp', 'tracks') }}
where popularity < 0 or popularity > 100
 