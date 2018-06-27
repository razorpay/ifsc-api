FROM redis:alpine

LABEL maintainer "Team Razorpay <contact@razorpay.com>"

ARG BUILD_DATE
ARG VCS_REF

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

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Razorpay IFSC API" \
      org.label-schema.vcs-url="https://github.com/razorpay/ifsc-api.git" \
      org.label-schema.url="https://ifsc.razorpay.com" \
      org.label-schema.vendor="Razorpay" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="1.0.0-rc1"

EXPOSE 3000

ENTRYPOINT ["/app/entrypoint.sh"]
