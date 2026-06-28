FROM ruby:3.4-alpine

RUN apk add --no-cache build-base openssl-dev

ARG RIVULET_VERSION=
RUN gem install "rivulet-rb${RIVULET_VERSION:+:$RIVULET_VERSION}" falcon

ENV PATH="/usr/local/bundle/bin:$PATH"

WORKDIR /app

ENTRYPOINT ["rivulet"]
CMD ["--help"]
