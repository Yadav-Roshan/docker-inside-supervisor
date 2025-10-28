#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to forward signals to the child process
_forward_signal() {
  echo "Caught signal $_signal, forwarding to Superset process PID $APP_PID"
  # Use kill to send the same signal to the Superset process
  kill -$_signal "$APP_PID"
  # Wait for the process to exit
  wait "$APP_PID"
}

# Trap TERM and INT signals and forward them to the Superset process
trap '_signal="TERM"; _forward_signal' TERM
trap '_signal="INT"; _forward_signal' INT

# --- Superset-specific initialization ---
# This part is idempotent and ensures the DB is ready before starting.
echo "Initializing Superset database..."
superset db upgrade
echo "Initializing Superset..."
superset init

# --- Start the main application in the background ---
# We use 'gosu' to run the command as the 'superset' user for better security.
echo "Starting Superset application..."
gosu superset superset run -p 8088 -h 0.0.0.0 --with-threads &

# Capture the PID of the backgrounded gosu process
APP_PID=$!
echo "Superset application started with PID: $APP_PID"

# --- Health Monitoring Loop ---
LICENSE_URL="http://license-monitor/health.txt"
echo "Starting license monitoring for: $LICENSE_URL"

while true; do
  # Check if the Superset process is still running. If not, exit.
  # This handles the case where the application crashes on its own.
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "Superset process has died unexpectedly. Exiting."
    exit 1
  fi

  # Use curl to check the license monitor's health.
  if curl -sf "$LICENSE_URL" | grep -q "HEALTHY"; then
    # The ':' command is a no-op, effectively 'do nothing'
    :
  else
    echo "License monitor is UNHEALTHY! Initiating graceful shutdown of Superset."
    # Send SIGTERM to the gosu/superset process. Gunicorn will handle it gracefully.
    kill -TERM "$APP_PID"
    break
  fi
  sleep 5
done

echo "Waiting for Superset to terminate..."
wait "$APP_PID"
echo "Superset terminated. Exiting container."