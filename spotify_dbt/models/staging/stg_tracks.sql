with source as (
    select * from {{ source('spotify_oltp', 'tracks') }}
),

renamed as (
    select
        track_id,
        track_name,
        album_id,
        genre_id,
        popularity,
        round(duration_ms / 1000.0, 2) as duration_seconds,
        duration_ms,
        explicit,
        key,
        mode,
        time_signature
    from source
    where track_id is not null
      and track_name is not null
      and popularity between 0 and 100
      and duration_ms > 0
)

select * from renamed