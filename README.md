# Spotify Music Trends Analysis
EAS 550 | Vaishak Muralidharan

## Project Description
Interactive data visualization dashboard exploring Spotify music trends.

## Database
Hosted on Neon serverless PostgreSQL (AWS US East 1).

## Files
- `ERD_Spotify.png` — Entity Relationship Diagram (Crow's Foot notation)
- `schema.sql` — Database schema with all CREATE TABLE statements
- `ingest_data.py` — Data cleaning and ingestion pipeline
- `security.sql` — Role-Based Access Control setup
- `3NF_justification_report.md` — Schema design justification

## Neon CU Monitoring
- SQLAlchemy is configured with `NullPool` to ensure connections 
  close immediately after use, allowing Neon compute to sleep after 
  5 minutes of inactivity.
- CU usage is monitored regularly via the Neon Dashboard.
- Current usage: well within free tier (100 CU-hrs/month).

## Demo Video
[Link to be added]