# ---- Builder Stage ----
# This stage is now self-contained and manages its own temporary Redis instance.
# This is the most reliable approach as it has no external dependencies.
FROM ruby:3.1-alpine3.18 AS rdbbuilder

# Set the working directory
WORKDIR /app

# ** THE FIX **: Configure Bundler to install gems locally and add the gem bin path
# to the container's main PATH environment variable. This is the crucial change.
ENV BUNDLE_PATH="vendor/bundle" \
    BUNDLE_BIN="vendor/bundle/bin" \
    BUNDLE_GEMFILE="Gemfile.build"
ENV PATH="/app/vendor/bundle/bin:$PATH"

# Copy build-specific files
COPY Gemfile.build* init.rb /app/
COPY data /app/data/

RUN echo "** Builder: Installing OS and Bundler dependencies... **" && \
    apk --no-cache add redis && \
    gem install bundler -v 2.4.10

RUN echo "** Builder: Installing gems... **" && \
    bundle install --jobs=$(nproc) --retry 3

RUN echo "** Builder: Starting redis-server in the background... **" && \
    redis-server & REDIS_PID=$! && \
    echo "** Builder: Waiting for Redis to be ready... **" && \
    while ! redis-cli ping > /dev/null 2>&1; do sleep 1; done && \
    echo "** Builder: Redis is ready. Running build script... **" && \
    bundle exec ruby init.rb && \
    echo "** Builder: Build script finished. Shutting down Redis... **" && \
    redis-cli shutdown && \
    wait $REDIS_PID && \
    echo "** Builder: Redis shut down. Stage complete. **"


# ---- Final Stage ----
# This stage builds the final, lean runtime image for the application.
FROM ruby:3.1-alpine3.18

WORKDIR /app

# ** THE FIX **: Apply the same robust PATH configuration to the final image.
# This ensures the entrypoint script can find all the necessary executables.
ENV BUNDLE_PATH="vendor/bundle" \
    BUNDLE_BIN="vendor/bundle/bin" \
    BUNDLE_GEMFILE="Gemfile"
ENV PATH="/app/vendor/bundle/bin:$PATH"

# Install only the necessary runtime dependencies.
RUN echo "** Final: Installing OS dependencies... **" && \
    apk --no-cache add dumb-init redis libstdc++ curl

COPY Gemfile Gemfile.lock /app/

# Install production gems.
RUN echo "** Final: Installing gems... **" && \
    apk --no-cache add --virtual .build-deps g++ make && \
    gem install bundler -v 2.4.10 && \
    bundle config set --local without 'testing' && \
    bundle install --jobs=$(nproc) --retry 3 && \
    apk del .build-deps && \
    echo "** Final: Gem installation complete. **"

# Create a non-root user for security best practices.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    mkdir -p /data && \
    chown -R appuser:appgroup /data

USER appuser

COPY --from=rdbbuilder --chown=appuser:appgroup /app/dump.rdb /data/
COPY --chown=appuser:appgroup . .

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000 || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
