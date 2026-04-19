select af.track_id
from {{ source('spotify_oltp', 'audio_features') }} af
left join {{ source('spotify_oltp', 'tracks') }} t
    on af.track_id = t.track_id
where t.track_id is null
 