#!/usr/bin/dumb-init /bin/sh
# Use set -e to exit immediately if a command fails
set -e

# Define the directory where Redis will store its data.
# This directory is owned by the 'appuser'.
REDIS_DATA_DIR="/data"
PID_FILE="/tmp/redis.pid"

# This function is called when the container receives a SIGTERM or SIGINT signal.
# It ensures that Redis is shut down gracefully, allowing it to save its data.
_shutdown() {
  echo "Caught signal. Shutting down services gracefully..."

  # Use redis-cli to perform a graceful shutdown.
  # This command waits for the save process to complete.
  if [ -f $PID_FILE ]; then
    echo "Stopping Redis..."
    redis-cli shutdown
    # Wait for the PID file to be removed, indicating Redis has stopped
    while [ -f $PID_FILE ]; do
      sleep 0.1
    done
    echo "Redis stopped."
  fi

  # Wait for the main application process (rackup) to finish.
  # The 'wait' command will exit after the process with $APP_PID exits.
  wait "$APP_PID"
  echo "Application stopped."
}

# Trap the TERM and INT signals to call our shutdown function.
# dumb-init ensures these signals are correctly passed to this script.
trap _shutdown SIGTERM SIGINT

# Change to the application directory
cd /app

# Start the Redis server in the background (daemonized).
# We explicitly tell it where to store its data and PID file.
# Binding to 127.0.0.1 is a good security practice.
echo "Starting Redis..."
redis-server --daemonize yes --pidfile $PID_FILE --dir $REDIS_DATA_DIR --bind 127.0.0.1

# Wait until the Redis server is accepting connections before proceeding.
echo "Waiting for Redis to be ready..."
while ! redis-cli ping > /dev/null 2>&1; do
  sleep 1
done
echo "Redis is ready."

# Start the main Ruby application in the background and store its Process ID (PID).
echo "Starting application..."
bundle exec rackup --host 0.0.0.0 --port 3000 &
APP_PID=$!

# The 'wait' command pauses the script here and waits for the backgrounded
# application (rackup) to exit. This keeps the container running.
wait "$APP_PID"
