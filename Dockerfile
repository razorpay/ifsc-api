# ---- Builder Stage ----
# This stage is now self-contained and manages its own temporary Redis instance.
# This is the most reliable approach as it has no external dependencies.
FROM ruby:3.1-alpine3.18 AS rdbbuilder

WORKDIR /app
ENV BUNDLE_GEMFILE=Gemfile.build

COPY Gemfile.build* init.rb /app/
COPY data /app/data/

# This RUN command encapsulates the entire build process for the Redis data.
# It is a robust, multi-step script that ensures each stage completes successfully.
RUN echo "** Builder: Installing OS and Bundler dependencies... **" && \
    # Install Redis server locally within the build stage.
    apk --no-cache add redis && \
    # Install the specific version of Bundler required by the lockfile to prevent version conflicts.
    gem install bundler -v 2.4.10 && \
    # ** THE FIX **: Configure bundler to install gems into a local vendor directory.
    # This makes the gem location explicit and solves pathing issues within Docker.
    bundle config set --local path 'vendor/bundle' && \
    echo "** Builder: Installing gems... **" && \
    bundle install --jobs=$(nproc) --retry 3 && \
    echo "** Builder: Starting redis-server in the background... **" && \
    # Start Redis as a background job and capture its Process ID (PID).
    redis-server & REDIS_PID=$! && \
    echo "** Builder: Waiting for Redis to be ready... **" && \
    # This loop pauses the script until Redis is fully initialized and ready for connections.
    while ! redis-cli ping > /dev/null 2>&1; do sleep 1; done && \
    echo "** Builder: Redis is ready. Running build script... **" && \
    # Run the Ruby script to populate the Redis database.
    bundle exec ruby init.rb && \
    echo "** Builder: Build script finished. Shutting down Redis... **" && \
    # Gracefully shut down Redis, which ensures the data is saved to dump.rdb.
    redis-cli shutdown && \
    # CRITICAL STEP: Wait for the Redis server process to fully terminate before finishing the RUN command.
    # This prevents the build from hanging.
    wait $REDIS_PID && \
    echo "** Builder: Redis shut down. Stage complete. **"


# ---- Final Stage ----
# This stage builds the final, lean runtime image for the application.
FROM ruby:3.1-alpine3.18

WORKDIR /app
ENV BUNDLE_GEMFILE=Gemfile

# Install only the necessary runtime dependencies.
RUN echo "** Final: Installing OS dependencies... **" && \
    apk --no-cache add dumb-init redis libstdc++ curl

COPY Gemfile Gemfile.lock /app/

# Install production gems, also ensuring the correct Bundler version is used.
RUN echo "** Final: Installing gems... **" && \
    apk --no-cache add --virtual .build-deps g++ make && \
    gem install bundler -v 2.4.10 && \
    # ** THE FIX **: Also configure the final stage to use the local vendor directory.
    bundle config set --local path 'vendor/bundle' && \
    bundle config set --local without 'testing' && \
    bundle install --jobs=$(nproc) --retry 3 && \
    # Clean up the build dependencies to keep the final image small.
    apk del .build-deps && \
    echo "** Final: Gem installation complete. **"

# Create a non-root user for security best practices.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    # Create a data directory owned by the new user for Redis to use.
    mkdir -p /data && \
    chown -R appuser:appgroup /data

# Switch to the non-root user.
USER appuser

# Copy the pre-built Redis database from the builder stage.
COPY --from=rdbbuilder --chown=appuser:appgroup /app/dump.rdb /data/

# Copy the rest of the application files.
COPY --chown=appuser:appgroup . .

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000 || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
