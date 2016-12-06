FROM ruby:2.3

RUN gem install pg redis
ADD . /tmp/.
WORKDIR /tmp/
RUN chmod 777 main.rb

CMD ruby main.rb
