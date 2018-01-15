FROM redis:alpine

RUN apk --no-cache  add \
    ca-certificates \
    dumb-init \
    ruby \
    ruby-bundler \
    ruby-json \
    ruby-dev \
    && apk --no-cache add --virtual .eventmachine-builddeps g++ make \
    && rm -rf /var/cache/apk/* /tmp/*

RUN mkdir /app

COPY . /app

WORKDIR /app

RUN bundle install --no-ri --no-rdoc

COPY entrypoint.sh build.sh /app/

RUN /app/build.sh

EXPOSE 3000

RUN apk del .eventmachine-builddeps

ENTRYPOINT ["/app/entrypoint.sh"]
