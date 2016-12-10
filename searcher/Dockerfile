FROM ubuntu:yakkety

RUN apt-get update -y
RUN apt-get install -y apache2 php libapache2-mod-php php-pgsql php-curl php7.0-dev wget unzip

RUN sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf
RUN a2enmod rewrite

ADD . /var/www/html/

WORKDIR /tmp

RUN wget https://pecl.php.net/get/redis-3.0.0.tgz
RUN tar zxpf redis*
RUN cd redis* && phpize && ./configure && make && make install
RUN echo "extension=\"redis.so\"" > /etc/php/7.0/apache2/php.ini

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

EXPOSE 80
CMD /usr/sbin/apache2ctl -D FOREGROUND
