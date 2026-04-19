
    
    

select
    genre_name as unique_field,
    count(*) as n_records

from "neondb"."public"."genres"
where genre_name is not null
group by genre_name
having count(*) > 1


