#!/usr/bin/dumb-init /bin/sh
cd /app
redis-server &
bundle exec thin start