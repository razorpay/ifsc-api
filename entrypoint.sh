#!/usr/bin/dumb-init /bin/sh
cd /app
redis-server --daemonize yes
bundle exec thin start