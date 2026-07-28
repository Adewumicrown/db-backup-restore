#!/bin/bash
docker exec -i pg-db psql -U appuser -d appdb <<SQL
CREATE TABLE IF NOT EXISTS events (
  id SERIAL PRIMARY KEY,
  note TEXT,
  created_at TIMESTAMP DEFAULT now()
);
INSERT INTO events (note) VALUES ('seed row 1'), ('seed row 2');
SQL
