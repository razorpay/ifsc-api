# ---- Builder Stage ----
# This stage now relies on a Redis service provided by the CI environment
FROM ruby:3.1-alpine3.18 as rdbbuilder

WORKDIR /app
ENV BUNDLE_GEMFILE=Gemfile.build

# ARG is used to get the build-time variable from the 'docker build' command
ARG REDIS_HOST=localhost
# ENV makes the variable available to the commands run inside the container
ENV REDIS_HOST=$REDIS_HOST

COPY Gemfile.build* init.rb /app/
COPY data /app/data/

# We now install the specific version of bundler required by the lockfile.
# This avoids version conflicts with the base image's Ruby version.
RUN echo "** Builder: Installing correct bundler version... **" && \
    gem install bundler -v 2.4.10 && \
    echo "** Builder: Installing gems... **" && \
    bundle install --jobs=$(nproc) --retry 3 && \
    echo "** Builder: Running build script against Redis service at ${REDIS_HOST}... **" && \
    bundle exec ruby init.rb && \
    echo "** Builder: Stage complete. **"


# ---- Final Stage ----
# This stage defines the final runtime image.
FROM ruby:3.1-alpine3.18

WORKDIR /app
ENV BUNDLE_GEMFILE=Gemfile

RUN echo "** Final: Installing OS dependencies... **" && \
    apk --no-cache add dumb-init redis libstdc++ curl

COPY Gemfile Gemfile.lock /app/

# We also install the specific bundler version in the final stage for consistency.
RUN echo "** Final: Installing gems... **" && \
    apk --no-cache add --virtual .build-deps g++ make && \
    gem install bundler -v 2.4.10 && \
    bundle config set --local without 'testing' && \
    bundle install --jobs=$(nproc) --retry 3 && \
    apk del .build-deps && \
    echo "** Final: Gem installation complete. **"

RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    mkdir -p /data && \
    chown -R appuser:appgroup /data

USER appuser

# The dump.rdb is copied from the builder stage, which now generates it using the CI service.
COPY --from=rdbbuilder --chown=appuser:appgroup /app/dump.rdb /data/

COPY --chown=appuser:appgroup . .

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000 || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
