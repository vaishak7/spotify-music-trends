select track_id, popularity
from "neondb"."public"."tracks"
where popularity < 0 or popularity > 100