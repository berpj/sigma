FROM ruby:2.3

RUN gem install pg nokogiri addressable work_queue redis i18n
ADD app.rb /tmp/app.rb
WORKDIR /tmp/
RUN chmod 777 app.rb

CMD ruby app.rb
