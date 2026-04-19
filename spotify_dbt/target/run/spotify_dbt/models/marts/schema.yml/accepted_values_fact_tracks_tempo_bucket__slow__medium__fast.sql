
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        tempo_bucket as value_field,
        count(*) as n_records

    from "neondb"."public_marts"."fact_tracks"
    group by tempo_bucket

)

select *
from all_values
where value_field not in (
    'slow','medium','fast'
)



  
  
      
    ) dbt_internal_test