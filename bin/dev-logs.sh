#!/bin/bash

# Helper script to show live logs from ERPNext development container
# Usage: bash bin/dev-logs.sh

echo "📋 Showing live logs from ERPNext development container..."
echo "   Press Ctrl+C to stop watching logs"
echo ""

# Find the ERPNext app container
CONTAINER_NAME="erpnext-app"

if ! docker ps -q -f "name=$CONTAINER_NAME" | grep -q .; then
    echo "❌ ERPNext container '$CONTAINER_NAME' is not running"
    echo "   Start it with: make up or make up-build"
    exit 1
fi

echo "✅ Found container: $CONTAINER_NAME"
echo "🔍 Watching logs (with watchexec auto-reload info)..."
echo "────────────────────────────────────────────────────────"

# Follow logs with color and timestamps
docker logs -f --timestamps "$CONTAINER_NAME" 2>&1