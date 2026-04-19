select af.track_id
from "neondb"."public"."audio_features" af
left join "neondb"."public"."tracks" t
    on af.track_id = t.track_id
where t.track_id is null