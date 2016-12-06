FROM ruby:2.3

RUN gem install pg nokogiri addressable work_queue redis i18n
ADD . /tmp/.
WORKDIR /tmp/
RUN chmod 777 main.rb

CMD ruby main.rb
