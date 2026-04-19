
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with child as (
    select genre_id as from_field
    from "neondb"."public_marts"."fact_tracks"
    where genre_id is not null
),

parent as (
    select genre_id as to_field
    from "neondb"."public_marts"."dim_genre"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



  
  
      
    ) dbt_internal_test