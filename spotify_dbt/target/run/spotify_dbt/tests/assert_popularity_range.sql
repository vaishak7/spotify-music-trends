
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  select track_id, popularity
from "neondb"."public"."tracks"
where popularity < 0 or popularity > 100
  
  
      
    ) dbt_internal_test