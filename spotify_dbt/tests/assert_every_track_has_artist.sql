select t.track_id
from {{ source('spotify_oltp', 'tracks') }} t
left join {{ source('spotify_oltp', 'track_artists') }} ta
    on t.track_id = ta.track_id
where ta.track_id is null
 