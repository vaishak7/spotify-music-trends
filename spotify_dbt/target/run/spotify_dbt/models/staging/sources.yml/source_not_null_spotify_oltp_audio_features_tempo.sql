
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select tempo
from "neondb"."public"."audio_features"
where tempo is null



  
  
      
    ) dbt_internal_test