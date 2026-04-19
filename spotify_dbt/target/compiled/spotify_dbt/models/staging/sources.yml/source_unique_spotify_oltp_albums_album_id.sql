
    
    

select
    album_id as unique_field,
    count(*) as n_records

from "neondb"."public"."albums"
where album_id is not null
group by album_id
having count(*) > 1


