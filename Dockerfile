FROM ruby:3.4-alpine

WORKDIR /rivulet

COPY Gemfile rivulet.gemspec ./
COPY lib/ lib/
COPY bin/ bin/

RUN apk add --no-cache build-base openssl-dev && bundle install

ENV PATH="/usr/local/bundle/bin:$PATH"
ENV BUNDLE_GEMFILE=/rivulet/Gemfile

WORKDIR /app

CMD ["bundle", "exec", "falcon", "serve", "-n", "1", "-b", "http://0.0.0.0:9292"]
