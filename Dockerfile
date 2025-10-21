FROM ruby:3.4-slim

ENV RAILS_ENV=development \
    BUNDLER_VERSION=2.4.10 \
    LANG=C.UTF-8 \
    TZ=Asia/Bangkok

RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  libyaml-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN gem install bundler -v $BUNDLER_VERSION
RUN bundle install --jobs 4 --retry 3

COPY . .

EXPOSE 3003

CMD ["foreman", "start"]