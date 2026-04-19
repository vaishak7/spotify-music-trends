
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select track_id
from "neondb"."public"."track_artists"
where track_id is null



  
  
      
    ) dbt_internal_test