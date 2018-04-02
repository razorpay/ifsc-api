#!/bin/sh
cd /app
echo "[+] Starting redis"
redis-server --daemonize yes
bundle exec ruby init.rb
echo "[+] Redis data saved"
ls -la /
echo "[+] Removing extra files"
rm -rf /usr/lib/ruby/gems/2.4.0/cache
rm -rf /root/.bundle/cache/
rm -rf /usr/local/bin/redis-cli
rm -rf /usr/local/bin/redis-check-rdb
rm -rf /usr/local/bin/redis-check-aof
rm -rf /usr/local/bin/redis-benchmark