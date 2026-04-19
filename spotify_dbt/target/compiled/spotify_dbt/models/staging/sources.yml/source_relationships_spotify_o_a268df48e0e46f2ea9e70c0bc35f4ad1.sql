
    
    

with child as (
    select track_id as from_field
    from "neondb"."public"."track_artists"
    where track_id is not null
),

parent as (
    select track_id as to_field
    from "neondb"."public"."tracks"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


