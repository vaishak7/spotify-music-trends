-- models/marts/dim_artist.sql
-- EAS 550 | Vaishak Muralidharan
-- Star Schema Dimension: Artist
-- Enriched with aggregated track stats per artist

with artists as (
    select * from "neondb"."public_staging"."stg_artists"
),

track_artists as (
    select * from "neondb"."public"."track_artists"
),

tracks as (
    select * from "neondb"."public_staging"."stg_tracks"
),

artist_stats as (
    select
        ta.artist_id,
        count(distinct ta.track_id)      as total_tracks,
        round(avg(t.popularity), 2)      as avg_popularity,
        max(t.popularity)                as peak_popularity,
        count(distinct t.album_id)       as total_albums
    from track_artists ta
    join tracks t on ta.track_id = t.track_id
    group by ta.artist_id
)

select
    a.artist_id,
    a.artist_name,
    coalesce(s.total_tracks, 0)    as total_tracks,
    coalesce(s.avg_popularity, 0)  as avg_popularity,
    coalesce(s.peak_popularity, 0) as peak_popularity,
    coalesce(s.total_albums, 0)    as total_albums
from artists a
left join artist_stats s on a.artist_id = s.artist_id