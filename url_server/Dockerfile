FROM ruby:2.3

RUN gem install pg aws-sdk-v1
ADD app.rb /tmp/app.rb
WORKDIR /tmp/
RUN chmod 777 app.rb

CMD ruby app.rb
