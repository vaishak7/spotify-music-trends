
    
    

select
    artist_name as unique_field,
    count(*) as n_records

from "neondb"."public"."artists"
where artist_name is not null
group by artist_name
having count(*) > 1


