FROM redis:alpine

RUN apk --no-cache --update add \
    ca-certificates \
    build-base \
    dumb-init \
    ruby \
    ruby-bundler \
    ruby-dev \
    ruby-json \
    && rm -rf /var/cache/apk/* /tmp/*

RUN mkdir /app

COPY . /app

WORKDIR /app

RUN bundle install

EXPOSE 3000

COPY entrypoint.sh /app

ENTRYPOINT ["/app/entrypoint.sh"]
