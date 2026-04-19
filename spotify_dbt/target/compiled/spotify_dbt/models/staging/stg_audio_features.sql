with source as (
    select * from "neondb"."public"."audio_features"
),

cleaned as (
    select
        track_id,
        danceability,
        energy,
        loudness,
        speechiness,
        acousticness,
        instrumentalness,
        liveness,
        valence,
        tempo,
        case
            when tempo < 80  then 'slow'
            when tempo < 120 then 'medium'
            else 'fast'
        end as tempo_bucket,
        case
            when energy >= 0.75 then 'high'
            when energy >= 0.40 then 'medium'
            else 'low'
        end as energy_level
    from source
    where track_id is not null
      and danceability between 0 and 1
      and energy       between 0 and 1
      and loudness     between -60 and 5
      and tempo        > 0
)

select * from cleaned