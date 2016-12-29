FROM ruby:2.3

RUN gem install pg nokogiri addressable redis i18n aws-sdk-v1 stemmify
ADD . /tmp/.
WORKDIR /tmp/
RUN chmod 777 main.rb

CMD ruby main.rb
