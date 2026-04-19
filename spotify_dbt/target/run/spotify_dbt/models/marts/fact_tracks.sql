
  
    

  create  table "neondb"."public_marts"."fact_tracks__dbt_tmp"
  
  
    as
  
  (
    -- models/marts/fact_tracks.sql
-- EAS 550 | Vaishak Muralidharan
-- Star Schema FACT TABLE: fact_tracks
-- Central fact table joining all dimensions.
-- Grain: one row per track.

with tracks as (
    select * from "neondb"."public_staging"."stg_tracks"
),

audio as (
    select * from "neondb"."public_staging"."stg_audio_features"
),

-- Aggregate artist names per track for denormalization
track_artists as (
    select * from "neondb"."public"."track_artists"
),

artists as (
    select * from "neondb"."public_staging"."stg_artists"
),

artist_agg as (
    select
        ta.track_id,
        string_agg(a.artist_name, '; ' order by a.artist_name) as artist_names,
        count(*) as artist_count
    from track_artists ta
    join artists a on ta.artist_id = a.artist_id
    group by ta.track_id
)

select
    -- Keys
    t.track_id,
    t.album_id,
    t.genre_id,

    -- Track attributes
    t.track_name,
    t.popularity,
    t.duration_ms,
    t.duration_seconds,
    t.explicit,
    t.key,
    t.mode,
    t.time_signature,

    -- Artist info (denormalized for convenience)
    aa.artist_names,
    aa.artist_count,

    -- Audio features
    af.danceability,
    af.energy,
    af.loudness,
    af.speechiness,
    af.acousticness,
    af.instrumentalness,
    af.liveness,
    af.valence,
    af.tempo,
    af.tempo_bucket,
    af.energy_level,

    -- Derived metrics
    round((af.danceability + af.energy + af.valence) / 3.0, 4) as mood_score,
    round((af.acousticness + af.instrumentalness) / 2.0, 4)    as organic_score

from tracks t
left join audio      af on t.track_id = af.track_id
left join artist_agg aa on t.track_id = aa.track_id
  );
  