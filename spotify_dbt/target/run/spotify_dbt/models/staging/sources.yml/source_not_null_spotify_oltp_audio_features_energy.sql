
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select energy
from "neondb"."public"."audio_features"
where energy is null



  
  
      
    ) dbt_internal_test