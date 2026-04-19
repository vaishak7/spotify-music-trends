
  
    

  create  table "neondb"."public_marts"."dim_album__dbt_tmp"
  
  
    as
  
  (
    -- models/marts/dim_album.sql
-- EAS 550 | Vaishak Muralidharan
-- Star Schema Dimension: Album

with albums as (
    select * from "neondb"."public_staging"."stg_albums"
),

tracks as (
    select * from "neondb"."public_staging"."stg_tracks"
),

album_stats as (
    select
        album_id,
        count(*)                    as total_tracks,
        round(avg(popularity), 2)   as avg_popularity,
        sum(duration_ms)            as total_duration_ms
    from tracks
    group by album_id
)

select
    a.album_id,
    a.album_name,
    coalesce(s.total_tracks, 0)       as total_tracks,
    coalesce(s.avg_popularity, 0)     as avg_popularity,
    coalesce(s.total_duration_ms, 0)  as total_duration_ms
from albums a
left join album_stats s on a.album_id = s.album_id
  );
  