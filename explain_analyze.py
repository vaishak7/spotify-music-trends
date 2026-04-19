import os
from dotenv import load_dotenv
load_dotenv('.env')
import psycopg2

conn = psycopg2.connect(os.environ['DATABASE_URL'])
cur = conn.cursor()

query = """
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT g.genre_name, af.energy, af.valence, t.popularity
FROM tracks t
JOIN audio_features af ON t.track_id = af.track_id
JOIN genres g ON t.genre_id = g.genre_id
"""

cur.execute(query)
for row in cur.fetchall():
    print(row[0])

cur.close()
conn.close()