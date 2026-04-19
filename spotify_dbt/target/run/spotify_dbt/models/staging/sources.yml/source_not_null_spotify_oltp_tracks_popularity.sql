
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select popularity
from "neondb"."public"."tracks"
where popularity is null



  
  
      
    ) dbt_internal_test