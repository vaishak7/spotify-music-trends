
  
    

  create  table "neondb"."public_marts"."dim_genre__dbt_tmp"
  
  
    as
  
  (
    -- models/marts/dim_genre.sql
-- EAS 550 | Vaishak Muralidharan
-- Star Schema Dimension: Genre

with genres as (
    select * from "neondb"."public_staging"."stg_genres"
),

tracks as (
    select * from "neondb"."public_staging"."stg_tracks"
),

genre_stats as (
    select
        genre_id,
        count(*)                    as total_tracks,
        round(avg(popularity), 2)   as avg_popularity,
        sum(case when explicit then 1 else 0 end) as explicit_tracks
    from tracks
    group by genre_id
)

select
    g.genre_id,
    g.genre_name,
    coalesce(s.total_tracks, 0)     as total_tracks,
    coalesce(s.avg_popularity, 0)   as avg_popularity,
    coalesce(s.explicit_tracks, 0)  as explicit_tracks
from genres g
left join genre_stats s on g.genre_id = s.genre_id
  );
  