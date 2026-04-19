
    
    

select
    track_id as unique_field,
    count(*) as n_records

from "neondb"."public"."audio_features"
where track_id is not null
group by track_id
having count(*) > 1


