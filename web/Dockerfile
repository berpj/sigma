FROM ubuntu:yakkety

RUN apt-get update -y
RUN apt-get install -y apache2

RUN printf "<IfModule mod_dir.c>\nDirectoryIndex index.html\n</IfModule>\n" > /etc/apache2/mods-enabled/dir.conf

RUN sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf
RUN a2enmod rewrite

ADD . /var/www/html/

WORKDIR /tmp

EXPOSE 80
CMD /usr/sbin/apache2ctl -D FOREGROUND
