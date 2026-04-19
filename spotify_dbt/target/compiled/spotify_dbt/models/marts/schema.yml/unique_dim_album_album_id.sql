
    
    

select
    album_id as unique_field,
    count(*) as n_records

from "neondb"."public_marts"."dim_album"
where album_id is not null
group by album_id
having count(*) > 1


