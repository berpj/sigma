FROM ruby:2.3

RUN gem install pg aws-sdk-v1
ADD . /tmp/.
WORKDIR /tmp/
RUN chmod 777 main.rb

CMD ruby main.rb
