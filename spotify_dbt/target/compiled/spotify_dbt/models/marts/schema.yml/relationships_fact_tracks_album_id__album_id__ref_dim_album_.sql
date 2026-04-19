
    
    

with child as (
    select album_id as from_field
    from "neondb"."public_marts"."fact_tracks"
    where album_id is not null
),

parent as (
    select album_id as to_field
    from "neondb"."public_marts"."dim_album"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


