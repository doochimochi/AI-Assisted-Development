"""Child Safety App — Kafka Consumer / Content Screener

Reads from 'content-screening' topic, analyses each message for harmful
patterns, writes incidents to Cassandra, indexes them in Elasticsearch,
and creates alerts for high/critical severity findings.
"""

import os
import json
import uuid
import time
import logging
from datetime import datetime, timezone

from kafka import KafkaConsumer
from cassandra.cluster import Cluster
from elasticsearch import Elasticsearch

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "localhost:9092")
CASSANDRA_HOST  = os.getenv("CASSANDRA_HOST", "localhost")
ES_HOST         = os.getenv("ELASTICSEARCH_HOST", "http://localhost:9200")

# ---------------------------------------------------------------------------
# Harmful-content patterns (keyword-based, expandable to ML model)
# ---------------------------------------------------------------------------
PATTERNS = {
    "critical": [
        "meet me alone", "don't tell your parents", "send me photos",
        "keep this secret", "i'll hurt you", "run away with me",
        "you're mature for your age",
    ],
    "high": [
        "where do you live", "are you home alone", "what's your address",
        "don't tell anyone", "block your parents", "your parents don't understand",
    ],
    "medium": [
        "send your number", "add me on", "voice call", "video call alone",
        "are you single", "boyfriend", "girlfriend",
    ],
    "low": [
        "stranger", "online friend", "private chat",
    ],
}


def classify(content: str) -> tuple[str, list[str]]:
    """Return (severity, matched_flags) for a piece of content."""
    text = content.lower()
    flags = []
    severity = "safe"

    for level in ("critical", "high", "medium", "low"):
        for phrase in PATTERNS[level]:
            if phrase in text:
                flags.append(phrase)
                if severity == "safe" or _severity_rank(level) > _severity_rank(severity):
                    severity = level

    return severity, flags


def _severity_rank(s: str) -> int:
    return {"safe": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}.get(s, 0)


# ---------------------------------------------------------------------------
# Persistence helpers
# ---------------------------------------------------------------------------

def get_cassandra():
    for _ in range(10):
        try:
            cluster = Cluster([CASSANDRA_HOST])
            session = cluster.connect("childsafety")
            return session
        except Exception as e:
            log.warning("Cassandra not ready: %s — retrying in 5s", e)
            time.sleep(5)
    raise RuntimeError("Cannot connect to Cassandra")


def get_es():
    es = Elasticsearch(ES_HOST)
    for _ in range(10):
        try:
            if es.ping():
                return es
        except Exception:
            pass
        log.warning("Elasticsearch not ready — retrying in 5s")
        time.sleep(5)
    raise RuntimeError("Cannot connect to Elasticsearch")


def save_incident(session, child_id, incident_id, content, flags, severity, source, detected_at):
    session.execute(
        """INSERT INTO incidents
           (child_id, incident_id, content, flags, severity, source, detected_at)
           VALUES (%s, %s, %s, %s, %s, %s, %s)""",
        (child_id, incident_id, content, flags, severity, source, detected_at),
    )


def index_incident(es_client, child_id, incident_id, content, flags, severity, source, detected_at):
    es_client.index(
        index="incidents",
        id=str(incident_id),
        document={
            "child_id":    str(child_id),
            "incident_id": str(incident_id),
            "content":     content,
            "flags":       flags,
            "severity":    severity,
            "source":      source,
            "detected_at": detected_at.isoformat(),
        },
    )


def create_alert(session, child_id, incident_id, severity, flags):
    alert_id = uuid.uuid4()
    message = (
        f"[{severity.upper()}] Potentially harmful content detected. "
        f"Matched: {', '.join(flags[:3])}{'...' if len(flags) > 3 else ''}."
    )
    session.execute(
        """INSERT INTO alerts
           (alert_id, child_id, incident_id, message, severity, sent_at, acknowledged)
           VALUES (%s, %s, %s, %s, %s, %s, false)""",
        (alert_id, child_id, incident_id, message, severity, datetime.now(timezone.utc)),
    )
    log.info("Alert created: %s (severity=%s)", alert_id, severity)


# ---------------------------------------------------------------------------
# Main consumer loop
# ---------------------------------------------------------------------------

def run():
    log.info("Initialising connections…")
    session = get_cassandra()
    es_client = get_es()

    consumer = KafkaConsumer(
        "content-screening",
        bootstrap_servers=KAFKA_BOOTSTRAP,
        value_deserializer=lambda b: json.loads(b.decode()),
        group_id="childsafety-screener",
        auto_offset_reset="earliest",
    )

    log.info("Listening on 'content-screening' topic…")

    for message in consumer:
        event = message.value
        log.info("Received event for child %s", event.get("child_id"))

        try:
            child_id    = uuid.UUID(event["child_id"])
            content     = event["content"]
            source      = event.get("source", "unknown")
            detected_at = datetime.now(timezone.utc)
            incident_id = uuid.uuid4()

            severity, flags = classify(content)
            log.info("  severity=%s flags=%s", severity, flags)

            if severity != "safe":
                save_incident(session, child_id, incident_id, content, flags, severity, source, detected_at)
                index_incident(es_client, child_id, incident_id, content, flags, severity, source, detected_at)

                # Alert parents for medium severity and above
                if _severity_rank(severity) >= _severity_rank("medium"):
                    create_alert(session, child_id, incident_id, severity, flags)
            else:
                log.info("  Content is clean — no action taken")

        except Exception as e:
            log.error("Error processing event: %s", e)


if __name__ == "__main__":
    run()
