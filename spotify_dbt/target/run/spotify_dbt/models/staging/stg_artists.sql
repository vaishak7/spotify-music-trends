
  create view "neondb"."public_staging"."stg_artists__dbt_tmp"
    
    
  as (
    with source as (
    select * from "neondb"."public"."artists"
)

select
    artist_id,
    trim(artist_name) as artist_name
from source
where artist_name is not null
  );