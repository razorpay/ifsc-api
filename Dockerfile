FROM ruby:alpine as rdbbuilder

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

FROM ruby:alpine

WORKDIR /app
# Being explicit here, not needed
ENV BUNDLE_GEMFILE=Gemfile

# Just copy enough to install dependencies and maintain cache
COPY Gemfile Gemfile.lock /app/

RUN echo "** installing deps **" && \
    apk --no-cache add dumb-init redis libstdc++ && \
    echo "** installing eventmachine-build-deps **" && \
    apk --no-cache add --virtual .eventmachine-builddeps g++ make && \
    echo "** updating bundler **" && \
    gem update bundler && \
    echo "** installing ruby gems **" && \
    bundle install && \
    echo "** removing eventmachine-build deps **" && \
    apk del .eventmachine-builddeps

LABEL maintainer "Team Razorpay <contact@razorpay.com>"

COPY --from=rdbbuilder /app/dump.rdb /app/
# This is not clean because we can't run a COPY . anymore
# Since that would copy the data directory
# We can't add data to dockerignore, since it is used in first stage
COPY README.md app.rb metrics.rb config.ru entrypoint.sh /app/
COPY public /app/public/
COPY views /app/views/
COPY data/sublet.json data/banknames.json /app/data/

ARG BUILD_DATE
ARG VCS_REF

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Razorpay IFSC API" \
      org.label-schema.vcs-url="https://github.com/razorpay/ifsc-api.git" \
      org.label-schema.url="https://ifsc.razorpay.com" \
      org.label-schema.vendor="Razorpay" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="1.0.0-rc1"

EXPOSE 3000
ENTRYPOINT ["/app/entrypoint.sh"]
