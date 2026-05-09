"""
app.py
======
EAS 550 | Vaishak Muralidharan
Spotify Music Trends — Streamlit Dashboard
Connects live to Neon PostgreSQL via connection pooling.
"""

import os
import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from db import get_connection

# ── Page config ──────────────────────────────────────────────
st.set_page_config(
    page_title="Spotify Music Trends",
    page_icon="🎵",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Custom CSS ────────────────────────────────────────────────
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Space+Mono:wght@400;700&family=DM+Sans:wght@300;400;600&display=swap');

    html, body, [class*="css"] {
        font-family: 'DM Sans', sans-serif;
    }
    .main { background-color: #0d0d0d; }
    .block-container { padding-top: 2rem; }

    h1, h2, h3 {
        font-family: 'Space Mono', monospace;
        color: #1DB954;
    }
    .metric-card {
        background: #1a1a1a;
        border: 1px solid #1DB954;
        border-radius: 12px;
        padding: 1.2rem;
        text-align: center;
    }
    .metric-value {
        font-family: 'Space Mono', monospace;
        font-size: 2rem;
        color: #1DB954;
        font-weight: 700;
    }
    .metric-label {
        color: #aaaaaa;
        font-size: 0.85rem;
        margin-top: 0.3rem;
    }
    .stSelectbox label, .stSlider label, .stMultiSelect label {
        color: #1DB954 !important;
        font-family: 'Space Mono', monospace;
        font-size: 0.8rem;
    }
    .sidebar .sidebar-content { background: #111111; }
</style>
""", unsafe_allow_html=True)


# ── Data loading with caching ─────────────────────────────────

@st.cache_data(ttl=300)
def load_overview_stats():
    conn = get_connection()
    df = pd.read_sql("""
        SELECT
            (SELECT COUNT(*) FROM tracks)                    AS total_tracks,
            (SELECT COUNT(*) FROM artists)                   AS total_artists,
            (SELECT COUNT(*) FROM albums)                    AS total_albums,
            (SELECT COUNT(*) FROM genres)                    AS total_genres,
            (SELECT ROUND(AVG(popularity)::NUMERIC, 1)
             FROM tracks)                                    AS avg_popularity,
            (SELECT COUNT(*) FROM tracks WHERE explicit)     AS explicit_tracks
    """, conn)
    conn.close()
    return df.iloc[0]


@st.cache_data(ttl=300)
def load_genre_popularity(limit=20):
    conn = get_connection()
    df = pd.read_sql(f"""
        SELECT
            g.genre_name,
            COUNT(t.track_id)                       AS total_tracks,
            ROUND(AVG(t.popularity)::NUMERIC, 2)    AS avg_popularity,
            ROUND(AVG(af.danceability)::NUMERIC, 4) AS avg_danceability,
            ROUND(AVG(af.energy)::NUMERIC, 4)       AS avg_energy,
            ROUND(AVG(af.valence)::NUMERIC, 4)      AS avg_valence
        FROM genres g
        JOIN tracks t        ON g.genre_id = t.genre_id
        JOIN audio_features af ON t.track_id = af.track_id
        GROUP BY g.genre_name
        HAVING COUNT(t.track_id) >= 10
        ORDER BY avg_popularity DESC
        LIMIT {limit}
    """, conn)
    conn.close()
    return df


@st.cache_data(ttl=300)
def load_audio_features_by_genre(genres):
    conn = get_connection()
    genre_list = "', '".join(genres)
    df = pd.read_sql(f"""
        SELECT
            g.genre_name,
            ROUND(AVG(af.danceability)::NUMERIC, 4)     AS danceability,
            ROUND(AVG(af.energy)::NUMERIC, 4)           AS energy,
            ROUND(AVG(af.valence)::NUMERIC, 4)          AS valence,
            ROUND(AVG(af.acousticness)::NUMERIC, 4)     AS acousticness,
            ROUND(AVG(af.instrumentalness)::NUMERIC, 4) AS instrumentalness,
            ROUND(AVG(af.speechiness)::NUMERIC, 4)      AS speechiness
        FROM genres g
        JOIN tracks t ON g.genre_id = t.genre_id
        JOIN audio_features af ON t.track_id = af.track_id
        WHERE g.genre_name IN ('{genre_list}')
        GROUP BY g.genre_name
    """, conn)
    conn.close()
    return df


@st.cache_data(ttl=300)
def load_artist_performance(limit=20):
    conn = get_connection()
    df = pd.read_sql(f"""
        SELECT
            a.artist_name,
            COUNT(DISTINCT ta.track_id)             AS total_tracks,
            ROUND(AVG(t.popularity)::NUMERIC, 2)    AS avg_popularity,
            MAX(t.popularity)                        AS peak_popularity,
            ROUND(AVG(af.energy)::NUMERIC, 4)       AS avg_energy,
            ROUND(AVG(af.danceability)::NUMERIC, 4) AS avg_danceability
        FROM artists a
        JOIN track_artists ta  ON a.artist_id = ta.artist_id
        JOIN tracks t          ON ta.track_id = t.track_id
        JOIN audio_features af ON t.track_id = af.track_id
        GROUP BY a.artist_name
        HAVING COUNT(DISTINCT ta.track_id) >= 5
        ORDER BY avg_popularity DESC
        LIMIT {limit}
    """, conn)
    conn.close()
    return df


@st.cache_data(ttl=300)
def load_mood_clusters():
    conn = get_connection()
    df = pd.read_sql("""
        SELECT
            g.genre_name,
            CASE
                WHEN af.valence >= 0.5 AND af.energy >= 0.5 THEN 'Happy / Energetic'
                WHEN af.valence >= 0.5 AND af.energy <  0.5 THEN 'Peaceful / Content'
                WHEN af.valence <  0.5 AND af.energy >= 0.5 THEN 'Angry / Intense'
                ELSE 'Sad / Melancholic'
            END AS mood,
            COUNT(*)                            AS track_count,
            ROUND(AVG(t.popularity)::NUMERIC,2) AS avg_popularity
        FROM tracks t
        JOIN audio_features af ON t.track_id = af.track_id
        JOIN genres g          ON t.genre_id  = g.genre_id
        GROUP BY g.genre_name, mood
        HAVING COUNT(*) >= 20
        ORDER BY track_count DESC
    """, conn)
    conn.close()
    return df


@st.cache_data(ttl=300)
def load_all_genres():
    conn = get_connection()
    df = pd.read_sql("""
        SELECT g.genre_name
        FROM genres g
        JOIN tracks t ON g.genre_id = t.genre_id
        GROUP BY g.genre_name
        HAVING COUNT(*) >= 10
        ORDER BY g.genre_name
    """, conn)
    conn.close()
    return df["genre_name"].tolist()


@st.cache_data(ttl=300)
def load_popularity_distribution(genre):
    conn = get_connection()
    df = pd.read_sql("""
        SELECT t.popularity
        FROM tracks t
        JOIN genres g ON t.genre_id = g.genre_id
        WHERE g.genre_name = %(genre)s
    """, conn, params={"genre": genre})
    conn.close()
    return df


# ── Sidebar ───────────────────────────────────────────────────
with st.sidebar:
    st.markdown("## 🎵 Spotify Trends")
    st.markdown("---")
    st.markdown("**EAS 550 | Vaishak Muralidharan**")
    st.markdown("Live data from Neon PostgreSQL")
    st.markdown("---")

    page = st.selectbox(
        "NAVIGATE TO",
        ["Overview", "Genre Analysis", "Audio Features", "Artist Performance", "Mood Clusters"]
    )

    st.markdown("---")
    top_n = st.slider("Top N results", min_value=5, max_value=50, value=20, step=5)


# ── Overview Page ─────────────────────────────────────────────
if page == "Overview":
    st.title("🎵 Spotify Music Trends")
    st.markdown("#### Live analytics dashboard — 114k tracks across 113 genres")
    st.markdown("---")

    stats = load_overview_stats()

    c1, c2, c3, c4, c5, c6 = st.columns(6)
    metrics = [
        (c1, f"{int(stats.total_tracks):,}", "Total Tracks"),
        (c2, f"{int(stats.total_artists):,}", "Artists"),
        (c3, f"{int(stats.total_albums):,}", "Albums"),
        (c4, f"{int(stats.total_genres)}", "Genres"),
        (c5, f"{float(stats.avg_popularity):.1f}", "Avg Popularity"),
        (c6, f"{int(stats.explicit_tracks):,}", "Explicit Tracks"),
    ]
    for col, val, label in metrics:
        with col:
            st.markdown(f"""
            <div class="metric-card">
                <div class="metric-value">{val}</div>
                <div class="metric-label">{label}</div>
            </div>""", unsafe_allow_html=True)

    st.markdown("---")
    st.markdown("### Top Genres by Popularity")
    genre_df = load_genre_popularity(top_n)

    fig = px.bar(
        genre_df, x="avg_popularity", y="genre_name",
        orientation="h", color="avg_popularity",
        color_continuous_scale="Greens",
        labels={"avg_popularity": "Avg Popularity", "genre_name": "Genre"},
        template="plotly_dark"
    )
    fig.update_layout(
        plot_bgcolor="#0d0d0d", paper_bgcolor="#0d0d0d",
        yaxis={"categoryorder": "total ascending"},
        coloraxis_showscale=False, height=600,
        margin=dict(l=0, r=0, t=20, b=0)
    )
    st.plotly_chart(fig, use_container_width=True)


# ── Genre Analysis Page ───────────────────────────────────────
elif page == "Genre Analysis":
    st.title("📊 Genre Analysis")
    st.markdown("---")

    genre_df = load_genre_popularity(top_n)
    all_genres = load_all_genres()

    selected_genre = st.selectbox("Select a genre to explore popularity distribution", all_genres)

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("#### Popularity vs Track Count")
        fig = px.scatter(
            genre_df, x="total_tracks", y="avg_popularity",
            size="total_tracks", color="avg_popularity",
            hover_name="genre_name",
            color_continuous_scale="Greens",
            template="plotly_dark",
            labels={"total_tracks": "Track Count", "avg_popularity": "Avg Popularity"}
        )
        fig.update_layout(
            plot_bgcolor="#0d0d0d", paper_bgcolor="#0d0d0d",
            coloraxis_showscale=False, height=400
        )
        st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.markdown(f"#### Popularity Distribution — {selected_genre}")
        dist_df = load_popularity_distribution(selected_genre)
        fig2 = px.histogram(
            dist_df, x="popularity", nbins=20,
            color_discrete_sequence=["#1DB954"],
            template="plotly_dark",
            labels={"popularity": "Popularity Score"}
        )
        fig2.update_layout(
            plot_bgcolor="#0d0d0d", paper_bgcolor="#0d0d0d", height=400
        )
        st.plotly_chart(fig2, use_container_width=True)

    st.markdown("#### Genre Data Table")
    st.dataframe(
        genre_df.rename(columns={
            "genre_name": "Genre", "total_tracks": "Tracks",
            "avg_popularity": "Avg Popularity", "avg_danceability": "Danceability",
            "avg_energy": "Energy", "avg_valence": "Valence"
        }),
        use_container_width=True, hide_index=True
    )


# ── Audio Features Page ───────────────────────────────────────
elif page == "Audio Features":
    st.title("🎛️ Audio Features")
    st.markdown("---")

    all_genres = load_all_genres()
    default_genres = all_genres[:6] if len(all_genres) >= 6 else all_genres

    selected_genres = st.multiselect(
        "Select genres to compare (2–8 recommended)",
        options=all_genres,
        default=default_genres
    )

    if len(selected_genres) < 2:
        st.warning("Please select at least 2 genres.")
    else:
        audio_df = load_audio_features_by_genre(selected_genres)
        features = ["danceability", "energy", "valence", "acousticness", "instrumentalness", "speechiness"]

        st.markdown("#### Radar Chart — Audio Fingerprint by Genre")
        fig = go.Figure()
        colors = px.colors.qualitative.Safe
        for i, row in audio_df.iterrows():
            values = [row[f] for f in features] + [row[features[0]]]
            fig.add_trace(go.Scatterpolar(
                r=values,
                theta=features + [features[0]],
                fill="toself",
                name=row["genre_name"],
                line_color=colors[i % len(colors)],
                opacity=0.7
            ))
        fig.update_layout(
            polar=dict(
                bgcolor="#1a1a1a",
                radialaxis=dict(visible=True, range=[0, 1], color="#555"),
                angularaxis=dict(color="#aaa")
            ),
            paper_bgcolor="#0d0d0d", template="plotly_dark",
            legend=dict(bgcolor="#1a1a1a", bordercolor="#333"),
            height=500
        )
        st.plotly_chart(fig, use_container_width=True)

        st.markdown("#### Feature Heatmap")
        heat_df = audio_df.set_index("genre_name")[features]
        fig2 = px.imshow(
            heat_df,
            color_continuous_scale="Greens",
            template="plotly_dark",
            labels={"color": "Value"},
            aspect="auto"
        )
        fig2.update_layout(
            paper_bgcolor="#0d0d0d", plot_bgcolor="#0d0d0d", height=350
        )
        st.plotly_chart(fig2, use_container_width=True)


# ── Artist Performance Page ───────────────────────────────────
elif page == "Artist Performance":
    st.title("🎤 Artist Performance")
    st.markdown("---")

    artist_df = load_artist_performance(top_n)

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("#### Top Artists by Avg Popularity")
        fig = px.bar(
            artist_df.head(15), x="avg_popularity", y="artist_name",
            orientation="h", color="avg_popularity",
            color_continuous_scale="Greens",
            template="plotly_dark",
            labels={"avg_popularity": "Avg Popularity", "artist_name": "Artist"}
        )
        fig.update_layout(
            plot_bgcolor="#0d0d0d", paper_bgcolor="#0d0d0d",
            yaxis={"categoryorder": "total ascending"},
            coloraxis_showscale=False, height=500
        )
        st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.markdown("#### Popularity vs Energy Bubble Chart")
        fig2 = px.scatter(
            artist_df, x="avg_energy", y="avg_popularity",
            size="total_tracks", color="avg_danceability",
            hover_name="artist_name",
            color_continuous_scale="Greens",
            template="plotly_dark",
            labels={
                "avg_energy": "Avg Energy",
                "avg_popularity": "Avg Popularity",
                "avg_danceability": "Danceability"
            }
        )
        fig2.update_layout(
            plot_bgcolor="#0d0d0d", paper_bgcolor="#0d0d0d", height=500
        )
        st.plotly_chart(fig2, use_container_width=True)

    st.markdown("#### Artist Data Table")
    st.dataframe(
        artist_df.rename(columns={
            "artist_name": "Artist", "total_tracks": "Tracks",
            "avg_popularity": "Avg Popularity", "peak_popularity": "Peak Popularity",
            "avg_energy": "Energy", "avg_danceability": "Danceability"
        }),
        use_container_width=True, hide_index=True
    )


# ── Mood Clusters Page ────────────────────────────────────────
elif page == "Mood Clusters":
    st.title("🧠 Mood Clusters")
    st.markdown("#### Based on Russell's Circumplex Model (Energy × Valence)")
    st.markdown("---")

    mood_df = load_mood_clusters()

    moods = mood_df["mood"].unique().tolist()
    selected_moods = st.multiselect(
        "Filter by mood", options=moods, default=moods
    )
    filtered = mood_df[mood_df["mood"].isin(selected_moods)]

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("#### Track Distribution by Mood")
        mood_total = filtered.groupby("mood")["track_count"].sum().reset_index()
        fig = px.pie(
            mood_total, values="track_count", names="mood",
            color_discrete_sequence=["#1DB954", "#17a349", "#0d6e30", "#69c97a"],
            template="plotly_dark", hole=0.4
        )
        fig.update_layout(paper_bgcolor="#0d0d0d", height=400)
        st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.markdown("#### Top Genres per Mood")
        top_mood = filtered.sort_values("track_count", ascending=False).groupby("mood").head(3)
        fig2 = px.bar(
            top_mood, x="track_count", y="genre_name",
            color="mood", orientation="h",
            color_discrete_sequence=["#1DB954", "#17a349", "#0d6e30", "#69c97a"],
            template="plotly_dark",
            labels={"track_count": "Tracks", "genre_name": "Genre", "mood": "Mood"}
        )
        fig2.update_layout(
            plot_bgcolor="#0d0d0d", paper_bgcolor="#0d0d0d",
            yaxis={"categoryorder": "total ascending"}, height=400
        )
        st.plotly_chart(fig2, use_container_width=True)

    st.markdown("#### Mood × Genre Heatmap")
    pivot = filtered.pivot_table(index="genre_name", columns="mood", values="track_count", fill_value=0)
    fig3 = px.imshow(
        pivot, color_continuous_scale="Greens",
        template="plotly_dark", aspect="auto",
        labels={"color": "Tracks"}
    )
    fig3.update_layout(paper_bgcolor="#0d0d0d", plot_bgcolor="#0d0d0d", height=500)
    st.plotly_chart(fig3, use_container_width=True)