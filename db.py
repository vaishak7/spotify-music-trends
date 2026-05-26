"""
db.py
=====
EAS 550 | Vaishak Muralidharan
Secure database connection via psycopg2.
Reads DATABASE_URL from environment — never hardcoded.
"""

import os
import pandas as pd
import psycopg2
from psycopg2 import pool
import streamlit as st

@st.cache_resource
def get_pool():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise ValueError("DATABASE_URL environment variable not set.")
    return psycopg2.pool.SimpleConnectionPool(
        minconn=1,
        maxconn=10,
        dsn=database_url
    )

def run_query(sql, params=None):
    p = get_pool()
    conn = p.getconn()
    try:
        df = pd.read_sql(sql, conn, params=params)
        return df
    finally:
        p.putconn(conn)