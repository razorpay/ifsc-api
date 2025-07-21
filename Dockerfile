# ---- Builder Stage ----
# Pre-builds the Redis database file (dump.rdb)
# Using a more recent, specific version of the ruby:alpine image
FROM ruby:3.1-alpine3.18 as rdbbuilder

WORKDIR /app
ENV BUNDLE_GEMFILE=Gemfile.build

COPY Gemfile.build* init.rb /app/
COPY data /app/data/

# The RUN command now runs redis-server as a background job and explicitly waits for it to finish.
RUN echo "** Builder: Installing dependencies... **" && \
    apk --no-cache add redis && \
    echo "** Builder: Installing gems... **" && \
    bundle install && \
    echo "** Builder: Starting redis-server in the background... **" && \
    # Start redis-server as a background process and capture its PID
    redis-server & REDIS_PID=$! && \
    echo "** Builder: Waiting for Redis to be ready... **" && \
    # Wait for the server to start accepting connections
    while ! redis-cli ping > /dev/null 2>&1; do sleep 1; done && \
    echo "** Builder: Redis is ready. Running build script... **" && \
    bundle exec ruby init.rb && \
    echo "** Builder: Build script finished. Shutting down Redis... **" && \
    redis-cli shutdown && \
    # Explicitly wait for the redis-server process to stop
    wait $REDIS_PID && \
    echo "** Builder: Redis shut down. Stage complete. **"


# ---- Final Stage ----
# Creates the final, lean image for the application
FROM ruby:3.1-alpine3.18

WORKDIR /app
ENV BUNDLE_GEMFILE=Gemfile

# Install runtime dependencies
# dumb-init: A proper init system for containers
# redis: To run the redis-server
# libstdc++: Common C++ library dependency for some gems
# curl: For the healthcheck
RUN echo "** Final: Installing OS dependencies... **" && \
    apk --no-cache add dumb-init redis libstdc++ curl

# Copy only Gemfiles to leverage Docker layer caching
COPY Gemfile Gemfile.lock /app/

# Install gems, cleaning up build dependencies afterwards
RUN echo "** Final: Installing gems... **" && \
    apk --no-cache add --virtual .build-deps g++ make && \
    gem update bundler && \
    bundle config set --local without 'testing' && \
    bundle install --jobs=$(nproc) --retry 3 && \
    apk del .build-deps && \
    echo "** Final: Gem installation complete. **"

# Create a non-root user and a data directory for it to own
# This prevents permission errors for Redis
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    mkdir -p /data && \
    chown -R appuser:appgroup /data

# Switch to the non-root user for security
USER appuser

# Copy the pre-built database from the builder stage into the user-owned data directory
COPY --from=rdbbuilder --chown=appuser:appgroup /app/dump.rdb /data/

# Copy the rest of the application files
# .dockerignore prevents the 'data' directory from being copied here
COPY --chown=appuser:appgroup . .

EXPOSE 3000

# This healthcheck waits for the app to be ready before marking the container as healthy
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000 || exit 1

# Use the entrypoint script to start services
ENTRYPOINT ["/app/entrypoint.sh"]
