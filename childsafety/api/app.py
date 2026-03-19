"""Child Safety App — REST API

Endpoints:
  POST /children            Register a child profile
  GET  /children/<child_id> Get child profile + incident summary
  POST /content             Submit content for screening (→ Kafka)
  GET  /incidents           Full-text search incidents (Elasticsearch)
  GET  /incidents/<child_id> Recent incidents for a child (Cassandra)
  GET  /alerts/<child_id>   Pending alerts for a child
  POST /alerts/<alert_id>/ack  Acknowledge an alert
"""

import os
import json
import uuid
from datetime import datetime, timezone

from flask import Flask, request, jsonify
from flask_cors import CORS
from kafka import KafkaProducer

from db import get_cassandra_session, get_es_client

app = Flask(__name__)
CORS(app)

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "localhost:9092")

# Lazy globals initialised once on first request
_cassandra = None
_es = None
_producer = None


def cassandra():
    global _cassandra
    if _cassandra is None:
        _cassandra = get_cassandra_session()
    return _cassandra


def es():
    global _es
    if _es is None:
        _es = get_es_client()
    return _es


def producer():
    global _producer
    if _producer is None:
        _producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP,
            value_serializer=lambda v: json.dumps(v).encode(),
        )
    return _producer


# ---------------------------------------------------------------------------
# Children
# ---------------------------------------------------------------------------

@app.post("/children")
def register_child():
    data = request.get_json(force=True)
    if not data.get("name") or not data.get("age"):
        return jsonify({"error": "name and age are required"}), 400

    child_id = uuid.uuid4()
    parent_id = uuid.UUID(data["parent_id"]) if data.get("parent_id") else uuid.uuid4()
    now = datetime.now(timezone.utc)

    cassandra().execute(
        """INSERT INTO children (child_id, name, age, parent_id, created_at)
           VALUES (%s, %s, %s, %s, %s)""",
        (child_id, data["name"], int(data["age"]), parent_id, now),
    )
    return jsonify({"child_id": str(child_id), "parent_id": str(parent_id)}), 201


@app.get("/children/<child_id>")
def get_child(child_id):
    row = cassandra().execute(
        "SELECT * FROM children WHERE child_id = %s", (uuid.UUID(child_id),)
    ).one()
    if not row:
        return jsonify({"error": "child not found"}), 404
    return jsonify({
        "child_id":   str(row.child_id),
        "name":       row.name,
        "age":        row.age,
        "parent_id":  str(row.parent_id),
        "created_at": row.created_at.isoformat(),
    })


# ---------------------------------------------------------------------------
# Content screening  (produce to Kafka)
# ---------------------------------------------------------------------------

@app.post("/content")
def submit_content():
    data = request.get_json(force=True)
    if not data.get("child_id") or not data.get("content"):
        return jsonify({"error": "child_id and content are required"}), 400

    event = {
        "child_id":    data["child_id"],
        "content":     data["content"],
        "source":      data.get("source", "unknown"),
        "submitted_at": datetime.now(timezone.utc).isoformat(),
    }
    producer().send("content-screening", event)
    producer().flush()
    return jsonify({"status": "queued", "event": event}), 202


# ---------------------------------------------------------------------------
# Incidents  (read from Cassandra + Elasticsearch)
# ---------------------------------------------------------------------------

@app.get("/incidents")
def search_incidents():
    """Full-text search over all incidents using Elasticsearch."""
    q = request.args.get("q", "")
    severity = request.args.get("severity")
    size = int(request.args.get("size", 20))

    must = [{"match": {"content": q}}] if q else [{"match_all": {}}]
    filters = []
    if severity:
        filters.append({"term": {"severity": severity}})

    body = {
        "size": size,
        "query": {"bool": {"must": must, "filter": filters}},
        "sort": [{"detected_at": "desc"}],
    }
    result = es().search(index="incidents", body=body)
    hits = [h["_source"] for h in result["hits"]["hits"]]
    return jsonify({"total": result["hits"]["total"]["value"], "incidents": hits})


@app.get("/incidents/<child_id>")
def child_incidents(child_id):
    """Recent incidents for a specific child from Cassandra."""
    limit = int(request.args.get("limit", 50))
    rows = cassandra().execute(
        "SELECT * FROM incidents WHERE child_id = %s LIMIT %s",
        (uuid.UUID(child_id), limit),
    )
    incidents = [
        {
            "incident_id": str(r.incident_id),
            "content":     r.content,
            "flags":       list(r.flags or []),
            "severity":    r.severity,
            "source":      r.source,
            "detected_at": r.detected_at.isoformat(),
        }
        for r in rows
    ]
    return jsonify({"child_id": child_id, "incidents": incidents})


# ---------------------------------------------------------------------------
# Alerts
# ---------------------------------------------------------------------------

@app.get("/alerts/<child_id>")
def get_alerts(child_id):
    rows = cassandra().execute(
        "SELECT * FROM alerts WHERE child_id = %s ALLOW FILTERING",
        (uuid.UUID(child_id),),
    )
    alerts = [
        {
            "alert_id":      str(r.alert_id),
            "incident_id":   str(r.incident_id),
            "message":       r.message,
            "severity":      r.severity,
            "sent_at":       r.sent_at.isoformat(),
            "acknowledged":  r.acknowledged,
        }
        for r in rows
    ]
    return jsonify({"child_id": child_id, "alerts": alerts})


@app.post("/alerts/<alert_id>/ack")
def ack_alert(alert_id):
    cassandra().execute(
        "UPDATE alerts SET acknowledged = true WHERE alert_id = %s",
        (uuid.UUID(alert_id),),
    )
    return jsonify({"alert_id": alert_id, "acknowledged": True})


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=False)
