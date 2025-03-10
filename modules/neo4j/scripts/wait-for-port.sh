#!/bin/bash
# Script to wait for Bolt to become available and signal deployment success.
# Usage: wait-for-port.sh <host> <port> <timeout_in_seconds>

HOST=$1
PORT=$2
TIMEOUT=${3:-600}
INTERVAL=10
ELAPSED=0

echo "Waiting for port $PORT on $HOST to become available..."

while [ $ELAPSED -lt $TIMEOUT ]; do
  if nc -z -w 5 $HOST $PORT 2>/dev/null; then
    echo "Port $PORT on $HOST is now available!"
    exit 0
  fi
  
  if [ $((ELAPSED % 30)) -eq 0 ]; then
    echo "Still waiting for port $PORT on $HOST... ($ELAPSED/$TIMEOUT seconds elapsed)"
  fi
  
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "Timed out waiting for port $PORT on $HOST after $TIMEOUT seconds."
exit 1 