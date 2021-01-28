#!/usr/bin/dumb-init /bin/sh
cd /app
redis-server --daemonize yes
bundle exec rackup --host 0.0.0.0 --port 3000
