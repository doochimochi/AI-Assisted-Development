"""
Child Safety App — Standalone Demo
===================================
Runs the full pipeline in-process using in-memory mocks for
Cassandra, Elasticsearch, and Kafka.  No external services needed.
"""

import uuid
import json
from datetime import datetime, timezone
from collections import defaultdict

# ── ANSI colour helpers ──────────────────────────────────────────────────────
RED    = "\033[91m"
YELLOW = "\033[93m"
GREEN  = "\033[92m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
DIM    = "\033[2m"
RESET  = "\033[0m"

def banner(title):
    print(f"\n{BOLD}{CYAN}{'═'*60}{RESET}")
    print(f"{BOLD}{CYAN}  {title}{RESET}")
    print(f"{BOLD}{CYAN}{'═'*60}{RESET}")

def step(msg):
    print(f"\n{BOLD}▶  {msg}{RESET}")

def ok(msg):
    print(f"  {GREEN}✔{RESET}  {msg}")

def warn(msg):
    print(f"  {YELLOW}⚠{RESET}  {msg}")

def crit(msg):
    print(f"  {RED}✖{RESET}  {msg}")

def info(msg):
    print(f"  {DIM}{msg}{RESET}")

def pjson(obj):
    print(f"  {DIM}{json.dumps(obj, indent=4, default=str)}{RESET}")


# ── In-memory stores (mocking Cassandra tables) ──────────────────────────────

children_table  = {}   # child_id → row
incidents_table = defaultdict(list)  # child_id → [rows]
alerts_table    = defaultdict(list)  # child_id → [rows]

# Kafka queue (in-process list)
kafka_queue = []

# Elasticsearch index (list of docs)
es_index = []


# ── Classifier (same logic as consumer/consumer.py) ──────────────────────────

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
        "are you single",
    ],
    "low": [
        "stranger", "online friend", "private chat",
    ],
}

RANK = {"safe": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}

def classify(content: str):
    text = content.lower()
    flags, severity = [], "safe"
    for level in ("critical", "high", "medium", "low"):
        for phrase in PATTERNS[level]:
            if phrase in text:
                flags.append(phrase)
                if RANK[level] > RANK[severity]:
                    severity = level
    return severity, flags


# ── API layer (plain Python, mirrors Flask routes) ────────────────────────────

def api_register_child(name, age, parent_id=None):
    child_id  = str(uuid.uuid4())
    parent_id = parent_id or str(uuid.uuid4())
    children_table[child_id] = {
        "child_id":   child_id,
        "name":       name,
        "age":        age,
        "parent_id":  parent_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    return children_table[child_id]


def api_submit_content(child_id, content, source="chat"):
    event = {
        "child_id":     child_id,
        "content":      content,
        "source":       source,
        "submitted_at": datetime.now(timezone.utc).isoformat(),
    }
    kafka_queue.append(event)           # → Kafka topic: content-screening
    return event


def api_get_incidents(child_id):
    return incidents_table[child_id]


def api_search_incidents(q="", severity=None):
    results = [
        doc for doc in es_index
        if (not q or q.lower() in doc["content"].lower())
        and (not severity or doc["severity"] == severity)
    ]
    return sorted(results, key=lambda d: d["detected_at"], reverse=True)


def api_get_alerts(child_id):
    return alerts_table[child_id]


def api_ack_alert(child_id, alert_id):
    for alert in alerts_table[child_id]:
        if alert["alert_id"] == alert_id:
            alert["acknowledged"] = True
            return True
    return False


# ── Kafka consumer (same logic as consumer/consumer.py) ──────────────────────

def process_kafka_queue():
    """Drain the Kafka queue — simulates the consumer service."""
    while kafka_queue:
        event = kafka_queue.pop(0)
        child_id    = event["child_id"]
        content     = event["content"]
        source      = event["source"]
        detected_at = datetime.now(timezone.utc).isoformat()
        incident_id = str(uuid.uuid4())

        severity, flags = classify(content)

        if severity != "safe":
            # → Cassandra
            incident = {
                "incident_id": incident_id,
                "child_id":    child_id,
                "content":     content,
                "flags":       flags,
                "severity":    severity,
                "source":      source,
                "detected_at": detected_at,
            }
            incidents_table[child_id].append(incident)

            # → Elasticsearch
            es_index.append(incident.copy())

            # → Alert (medium+)
            if RANK[severity] >= RANK["medium"]:
                alert_id = str(uuid.uuid4())
                message  = (
                    f"[{severity.upper()}] Harmful content detected. "
                    f"Matched: {', '.join(flags[:3])}{'…' if len(flags) > 3 else ''}."
                )
                alerts_table[child_id].append({
                    "alert_id":     alert_id,
                    "child_id":     child_id,
                    "incident_id":  incident_id,
                    "message":      message,
                    "severity":     severity,
                    "sent_at":      detected_at,
                    "acknowledged": False,
                })

        return severity, flags, incident_id if severity != "safe" else None


# ── Demo script ───────────────────────────────────────────────────────────────

SEVERITY_COLOR = {
    "safe":     GREEN,
    "low":      DIM,
    "medium":   YELLOW,
    "high":     RED,
    "critical": RED + BOLD,
}

TEST_MESSAGES = [
    ("Hey, want to play Minecraft after school?",           "chat",  "safe"),
    ("I made a new friend online. They seem nice.",         "chat",  "low"),
    ("Are you home alone right now?",                       "dm",    "high"),
    ("Don't tell your parents we're talking.",              "dm",    "critical"),
    ("You're mature for your age. Meet me alone.",          "dm",    "critical"),
    ("Add me on Discord, send your number.",                "chat",  "medium"),
    ("Let's do a video call alone tonight.",                "dm",    "medium"),
    ("Your parents don't understand you like I do.",        "dm",    "high"),
]


def main():
    banner("Child Safety App — Live Demo")
    print(f"""
  Architecture:
  {CYAN}POST /content{RESET} → {YELLOW}Kafka{RESET} → {CYAN}Consumer/Classifier{RESET}
       ↓                                    ↓
  {GREEN}Flask API{RESET}              {BOLD}Cassandra{RESET} (incidents + alerts)
                                    {BOLD}Elasticsearch{RESET} (full-text index)
""")

    # ── Step 1: Register a child ─────────────────────────────────────────────
    step("1. Register a child profile  →  POST /children")
    child = api_register_child("Alex", 10)
    ok(f"Child registered:  name={BOLD}{child['name']}{RESET}, age={child['age']}")
    info(f"child_id  : {child['child_id']}")
    info(f"parent_id : {child['parent_id']}")

    child_id = child["child_id"]

    # ── Step 2: Submit messages ──────────────────────────────────────────────
    step("2. Submit messages for screening  →  POST /content  →  Kafka")
    print()

    for content, source, expected in TEST_MESSAGES:
        api_submit_content(child_id, content, source)
        severity, flags, incident_id = process_kafka_queue()

        color = SEVERITY_COLOR.get(severity, RESET)
        badge = f"{color}[{severity.upper():8}]{RESET}"
        src   = f"{DIM}({source}){RESET}"

        print(f"  {badge} {src}  \"{content[:60]}\"")
        if flags:
            info(f"  matched: {', '.join(flags)}")

    # ── Step 3: Show incidents from Cassandra ────────────────────────────────
    step("3. Query incidents for child  →  GET /incidents/<child_id>  (Cassandra)")
    incidents = api_get_incidents(child_id)
    print(f"\n  Total incidents stored: {BOLD}{len(incidents)}{RESET}")
    for inc in incidents:
        color = SEVERITY_COLOR.get(inc["severity"], RESET)
        print(f"\n  {color}[{inc['severity'].upper()}]{RESET}  {inc['content'][:70]}")
        info(f"  flags: {', '.join(inc['flags'])}")
        info(f"  id:    {inc['incident_id']}")

    # ── Step 4: Elasticsearch full-text search ───────────────────────────────
    step("4. Full-text search  →  GET /incidents?q=parents  (Elasticsearch)")
    hits = api_search_incidents(q="parents")
    print(f"\n  Results for query={BOLD}'parents'{RESET}: {len(hits)} hit(s)")
    for h in hits:
        color = SEVERITY_COLOR.get(h["severity"], RESET)
        print(f"  {color}[{h['severity'].upper()}]{RESET}  {h['content'][:70]}")

    step("5. Filter by severity  →  GET /incidents?severity=critical  (Elasticsearch)")
    crits = api_search_incidents(severity="critical")
    print(f"\n  Critical incidents: {BOLD}{len(crits)}{RESET}")
    for h in crits:
        print(f"  {RED+BOLD}[CRITICAL]{RESET}  {h['content'][:70]}")

    # ── Step 5: Alerts ───────────────────────────────────────────────────────
    step("6. Get parent alerts  →  GET /alerts/<child_id>  (Cassandra)")
    alerts = api_get_alerts(child_id)
    print(f"\n  Alerts generated (medium+ severity): {BOLD}{len(alerts)}{RESET}")
    for a in alerts:
        color = SEVERITY_COLOR.get(a["severity"], RESET)
        ack   = f"{GREEN}ACK{RESET}" if a["acknowledged"] else f"{YELLOW}PENDING{RESET}"
        print(f"\n  {color}[{a['severity'].upper()}]{RESET}  {ack}")
        print(f"  {a['message']}")
        info(f"  alert_id: {a['alert_id']}")

    # ── Step 6: Acknowledge an alert ─────────────────────────────────────────
    if alerts:
        first_alert = alerts[0]
        step("7. Acknowledge alert  →  POST /alerts/<alert_id>/ack")
        api_ack_alert(child_id, first_alert["alert_id"])
        ok(f"Alert {first_alert['alert_id'][:8]}… acknowledged")
        alerts_after = api_get_alerts(child_id)
        acked = sum(1 for a in alerts_after if a["acknowledged"])
        info(f"Acknowledged: {acked}/{len(alerts_after)} alerts")

    # ── Summary ──────────────────────────────────────────────────────────────
    banner("Demo Summary")
    safe_count = sum(1 for _, _, exp in TEST_MESSAGES if exp == "safe")
    flagged    = len(incidents)
    crit_count = len([i for i in incidents if i["severity"] == "critical"])
    high_count = len([i for i in incidents if i["severity"] == "high"])

    print(f"""
  Messages submitted : {len(TEST_MESSAGES)}
  Clean (safe)       : {GREEN}{safe_count}{RESET}
  Flagged            : {YELLOW}{flagged}{RESET}
    ├─ Critical      : {RED+BOLD}{crit_count}{RESET}
    ├─ High          : {RED}{high_count}{RESET}
    └─ Medium/Low    : {flagged - crit_count - high_count}
  Alerts raised      : {len(alerts)}
  ES index size      : {len(es_index)} docs

  {DIM}In production:{RESET}
  • Kafka decouples ingestion from screening (handles bursts)
  • Cassandra stores per-child time-series (high write throughput)
  • Elasticsearch enables full-text search across all incidents
  • Classifer in consumer.py swappable with an ML model
""")


if __name__ == "__main__":
    main()
