
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    genre_name as unique_field,
    count(*) as n_records

from "neondb"."public"."genres"
where genre_name is not null
group by genre_name
having count(*) > 1



  
  
      
    ) dbt_internal_test