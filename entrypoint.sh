#!/usr/bin/dumb-init /bin/sh
cd /app
bundle exec ruby init.rb
redis-server &
bundle exec thin start