FROM ruby:2.5

RUN apt-get update
RUN apt-get install -y postgresql-9.6

WORKDIR /src
ADD . /src/
