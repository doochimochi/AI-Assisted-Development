# Child Safety App

A real-time content screening platform that detects harmful or grooming-related messages directed at children.

## Architecture

```
POST /content
     │
     ▼
 Flask API  ──────────────────────► Kafka topic: content-screening
     │                                        │
     │ (reads)                                ▼
     │                               Kafka Consumer (Screener)
     │                                        │
     ├── Cassandra ◄──── incidents/alerts ────┤
     └── Elasticsearch ◄──── incident index ──┘
```

| Component        | Role                                                        |
|------------------|-------------------------------------------------------------|
| **Flask API**    | REST interface — register children, submit content, query   |
| **Kafka**        | Decouples content ingestion from screening logic            |
| **Consumer**     | Classifies content; writes incidents + alerts               |
| **Cassandra**    | Stores child profiles, incidents (time-series), alerts      |
| **Elasticsearch**| Full-text search across all incidents                       |

## Quick Start

```bash
cd childsafety
docker compose up --build
```

Services take ~60s to become healthy on first run.

## API

### Register a child
```bash
POST /children
{"name": "Alex", "age": 10, "parent_id": "<optional-uuid>"}
# → {"child_id": "...", "parent_id": "..."}
```

### Submit content for screening
```bash
POST /content
{"child_id": "<uuid>", "content": "the message text", "source": "chat"}
# → 202 Accepted — queued in Kafka immediately
```

### Get incidents for a child (Cassandra)
```bash
GET /incidents/<child_id>?limit=50
```

### Full-text search incidents (Elasticsearch)
```bash
GET /incidents?q=secret&severity=critical&size=20
```

### Get alerts for a child
```bash
GET /alerts/<child_id>
```

### Acknowledge an alert
```bash
POST /alerts/<alert_id>/ack
```

## Severity Levels

| Level      | Examples                                                     |
|------------|--------------------------------------------------------------|
| `critical` | "meet me alone", "send me photos", "don't tell your parents" |
| `high`     | "where do you live", "are you home alone"                    |
| `medium`   | "send your number", "video call alone"                       |
| `low`      | "stranger", "private chat"                                   |
| `safe`     | No patterns matched — no action taken                        |

Alerts are created for `medium` severity and above.

## Smoke Test

```bash
bash scripts/seed.sh
```

## Extending

- Replace keyword matching in `consumer/consumer.py → classify()` with an ML classifier
- Add WebSocket push for real-time parent notifications
- Add a parent dashboard frontend (React)
