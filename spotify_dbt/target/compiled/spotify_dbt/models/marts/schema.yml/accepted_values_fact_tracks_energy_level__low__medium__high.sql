
    
    

with all_values as (

    select
        energy_level as value_field,
        count(*) as n_records

    from "neondb"."public_marts"."fact_tracks"
    group by energy_level

)

select *
from all_values
where value_field not in (
    'low','medium','high'
)


