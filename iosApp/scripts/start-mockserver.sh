#!/usr/bin/env bash
# Builds and starts the standalone :mockserver in the background, then waits for GET /__ready.
# Usage (from anywhere): iosApp/scripts/start-mockserver.sh [port]   (default 8080)
# Stop it with: curl -X POST http://localhost:<port>/__shutdown
set -euo pipefail

PORT="${1:-${MOCK_PORT:-8080}}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOG="${MOCKSERVER_LOG:-$ROOT/mockserver.log}"

cd "$ROOT"
./gradlew --console=plain :mockserver:installDist
nohup mockserver/build/install/mockserver/bin/mockserver "$PORT" > "$LOG" 2>&1 &
echo "mockserver pid $! (log: $LOG)"

for _ in $(seq 1 60); do
  if curl -sf "http://localhost:$PORT/__ready" > /dev/null; then
    echo "mockserver ready on http://localhost:$PORT"
    exit 0
  fi
  sleep 1
done
echo "mockserver did not become ready" >&2
cat "$LOG" >&2
exit 1
