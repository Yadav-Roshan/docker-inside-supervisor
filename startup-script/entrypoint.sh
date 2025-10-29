#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to forward signals to the child process
_forward_signal() {
  echo "Caught signal $_signal, forwarding to Original process PID $APP_PID"
  # Use kill to send the same signal to the Original process
  kill -$_signal "$APP_PID"
  # Wait for the process to exit
  wait "$APP_PID"
}

# Trap TERM and INT signals and forward them to the Original process
trap '_signal="TERM"; _forward_signal' TERM
trap '_signal="INT"; _forward_signal' INT

# --- Application-specific initialization ---
"$@" &

# Capture the PID of the backgrounded gosu process
APP_PID=$!
echo "Application started with PID: $APP_PID"

# --- Health Monitoring Loop ---
LICENSE_URL="http://license/health.txt"
echo "Starting license monitoring for: $LICENSE_URL"

sleep 20

while true; do
  # Check if the Original process is still running. If not, exit.
  # This handles the case where the application crashes on its own.
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "Original process has died unexpectedly. Exiting."
    exit 1
  fi

  # Use curl to check the license monitor's health.
  # Capture curl output on failure for better debugging
  if ! output=$(curl -f "$LICENSE_URL") || ! echo "$output" | grep -q "HEALTHY"; then
    echo "License monitor is UNHEALTHY! Initiating graceful shutdown of Original process."
    # We check if output is empty. If curl fails to connect, output will be empty.
    # If it connects but gets the wrong content, we print the content.
    if [ -z "$output" ]; then
      echo "Reason: Failed to connect to or resolve $LICENSE_URL."
    else
      echo "Reason: Did not find 'HEALTHY' in the response. Got: $output"
    fi
    kill -TERM "$APP_PID"
    break
  fi
  sleep 5
done

echo "Waiting for Original process to terminate..."
wait "$APP_PID"
echo "Original process terminated. Exiting container."