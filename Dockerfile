FROM ruby:alpine3.16 as rdbbuilder

WORKDIR /app
ENV BUNDLE_GEMFILE=Gemfile.build

COPY Gemfile.build* init.rb /app/
COPY data /app/data/

RUN echo "** installing deps **" && \
    apk --no-cache add redis && \
    echo "** installing ruby gems **" && \
    bundle install && \
    echo "** starting redis-server **" && \
    redis-server --daemonize yes && \
    echo "** running build script **" && \
    bundle exec ruby init.rb

FROM ruby:alpine3.16

WORKDIR /app
# Being explicit here, not needed
ENV BUNDLE_GEMFILE=Gemfile

# Just copy enough to install dependencies and maintain cache
COPY Gemfile Gemfile.lock /app/

RUN echo "** installing deps **" && \
    apk --no-cache add dumb-init redis libstdc++ && \
    echo "** installing eventmachine-build-deps **" && \
    apk --no-cache add --virtual .eventmachine-builddeps g++ make && \
    echo "** install healthcheck deps **" && \
    apk --no-cache add curl && \
    echo "** updating bundler **" && \
    gem update bundler && \
    echo "** installing ruby gems **" && \
    bundle config set --local without 'testing' && \
    bundle install && \
    echo "** removing eventmachine-build deps **" && \
    apk del .eventmachine-builddeps

COPY --from=rdbbuilder /app/dump.rdb /app/
# This is not clean because we can't run a COPY . anymore
# Since that would copy the data directory
# We can't add data to dockerignore, since it is used in first stage
COPY README.md app.rb metrics.rb config.ru entrypoint.sh /app/
COPY public /app/public/
COPY views /app/views/

EXPOSE 3000

ENTRYPOINT ["/app/entrypoint.sh"]

# Create a group and user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Tell docker that all future commands should run as the appuser user
USER appuser

HEALTHCHECK --start-period=200s CMD curl -I http://localhost:3000 || exit 1

