
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select album_name
from "neondb"."public"."albums"
where album_name is null



  
  
      
    ) dbt_internal_test