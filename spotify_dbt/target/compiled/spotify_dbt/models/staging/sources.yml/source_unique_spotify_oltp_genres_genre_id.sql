
    
    

select
    genre_id as unique_field,
    count(*) as n_records

from "neondb"."public"."genres"
where genre_id is not null
group by genre_id
having count(*) > 1


