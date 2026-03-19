"""Cassandra and Elasticsearch client setup and schema initialization."""

import os
import time
from cassandra.cluster import Cluster
from cassandra.auth import PlainTextAuthProvider
from elasticsearch import Elasticsearch

CASSANDRA_HOST = os.getenv("CASSANDRA_HOST", "localhost")
ES_HOST = os.getenv("ELASTICSEARCH_HOST", "http://localhost:9200")


def get_cassandra_session():
    for attempt in range(10):
        try:
            cluster = Cluster([CASSANDRA_HOST])
            session = cluster.connect()
            _init_cassandra(session)
            return session
        except Exception as e:
            print(f"Cassandra not ready ({attempt+1}/10): {e}")
            time.sleep(5)
    raise RuntimeError("Could not connect to Cassandra")


def _init_cassandra(session):
    session.execute("""
        CREATE KEYSPACE IF NOT EXISTS childsafety
        WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1}
    """)
    session.set_keyspace("childsafety")

    session.execute("""
        CREATE TABLE IF NOT EXISTS children (
            child_id   uuid PRIMARY KEY,
            name       text,
            age        int,
            parent_id  uuid,
            created_at timestamp
        )
    """)

    session.execute("""
        CREATE TABLE IF NOT EXISTS incidents (
            child_id    uuid,
            incident_id uuid,
            content     text,
            flags       list<text>,
            severity    text,
            source      text,
            detected_at timestamp,
            PRIMARY KEY (child_id, detected_at, incident_id)
        ) WITH CLUSTERING ORDER BY (detected_at DESC)
    """)

    session.execute("""
        CREATE TABLE IF NOT EXISTS alerts (
            alert_id    uuid PRIMARY KEY,
            child_id    uuid,
            incident_id uuid,
            message     text,
            severity    text,
            sent_at     timestamp,
            acknowledged boolean
        )
    """)


def get_es_client():
    es = Elasticsearch(ES_HOST)
    for attempt in range(10):
        try:
            if es.ping():
                _init_es_index(es)
                return es
        except Exception:
            pass
        print(f"Elasticsearch not ready ({attempt+1}/10), retrying...")
        time.sleep(5)
    raise RuntimeError("Could not connect to Elasticsearch")


def _init_es_index(es: Elasticsearch):
    if not es.indices.exists(index="incidents"):
        es.indices.create(index="incidents", body={
            "mappings": {
                "properties": {
                    "child_id":     {"type": "keyword"},
                    "incident_id":  {"type": "keyword"},
                    "content":      {"type": "text"},
                    "flags":        {"type": "keyword"},
                    "severity":     {"type": "keyword"},
                    "source":       {"type": "keyword"},
                    "detected_at":  {"type": "date"},
                }
            }
        })
