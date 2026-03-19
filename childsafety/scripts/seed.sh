#!/usr/bin/env bash
# Quick smoke-test: register a child and submit some sample content.

API="http://localhost:5001"

echo "=== Registering child ==="
RESP=$(curl -s -X POST "$API/children" \
  -H "Content-Type: application/json" \
  -d '{"name":"Alex","age":10}')
echo "$RESP" | python3 -m json.tool
CHILD_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['child_id'])")

echo ""
echo "=== Submitting safe content ==="
curl -s -X POST "$API/content" \
  -H "Content-Type: application/json" \
  -d "{\"child_id\":\"$CHILD_ID\",\"content\":\"Hey, want to play Minecraft after school?\",\"source\":\"chat\"}" \
  | python3 -m json.tool

echo ""
echo "=== Submitting suspicious content ==="
curl -s -X POST "$API/content" \
  -H "Content-Type: application/json" \
  -d "{\"child_id\":\"$CHILD_ID\",\"content\":\"Don't tell your parents about our conversations.\",\"source\":\"chat\"}" \
  | python3 -m json.tool

echo ""
echo "=== Submitting critical content ==="
curl -s -X POST "$API/content" \
  -H "Content-Type: application/json" \
  -d "{\"child_id\":\"$CHILD_ID\",\"content\":\"You're mature for your age. Meet me alone after school.\",\"source\":\"dm\"}" \
  | python3 -m json.tool

echo ""
echo "Waiting 3s for consumer to process..."
sleep 3

echo ""
echo "=== Incidents for child ==="
curl -s "$API/incidents/$CHILD_ID" | python3 -m json.tool

echo ""
echo "=== Alerts for child ==="
curl -s "$API/alerts/$CHILD_ID" | python3 -m json.tool

echo ""
echo "=== Search incidents containing 'secret' ==="
curl -s "$API/incidents?q=secret" | python3 -m json.tool
