FROM redis:alpine

RUN mkdir /app
WORKDIR /app
COPY . /app

RUN echo "** installing deps **" && \
    apk --no-cache add \
    ca-certificates \
    dumb-init \
    ruby \
    ruby-bundler \
    ruby-json \
    ruby-dev && \
    echo "** installing eventmachine-build-deps **" && \
    apk --no-cache add --virtual .eventmachine-builddeps g++ make && \
    echo "** installing ruby gems **" && \
    bundle install && \
    echo "** running build script **" && \
    /app/build.sh && \
    echo "** removing eventmachine-build deps **" && \
    apk del .eventmachine-builddeps

EXPOSE 3000

ENTRYPOINT ["/app/entrypoint.sh"]
