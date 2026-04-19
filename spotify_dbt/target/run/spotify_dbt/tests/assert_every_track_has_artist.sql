
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  select t.track_id
from "neondb"."public"."tracks" t
left join "neondb"."public"."track_artists" ta
    on t.track_id = ta.track_id
where ta.track_id is null
  
  
      
    ) dbt_internal_test