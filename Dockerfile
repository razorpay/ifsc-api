FROM alpine:3.4

RUN apk update \
    && apk add ca-certificates \
	ruby \
	ruby-bundler \
	build-base \
	ruby-dev \
	ruby-json \
	&& rm -rf /var/cache/apk/*

RUN mkdir /app

COPY . /app

WORKDIR /app

RUN bundle install

EXPOSE 3000

ENTRYPOINT ["bundle","exec","thin","start"]
