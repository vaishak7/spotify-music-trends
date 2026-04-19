
    
    

with child as (
    select genre_id as from_field
    from "neondb"."public"."tracks"
    where genre_id is not null
),

parent as (
    select genre_id as to_field
    from "neondb"."public"."genres"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


