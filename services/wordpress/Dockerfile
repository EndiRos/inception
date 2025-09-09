FROM alpine:3.18

RUN apk update && apk add --no-cache \
    php82 \
    php82-fpm \
    php82-mysqli \
    php82-json \
    php82-openssl \
    php82-curl \
    php82-zlib \
    php82-xml \
    php82-phar \
    php82-intl \
    php82-dom \
    php82-xmlreader \
    php82-ctype \
    php82-session \
    php82-mbstring \
    curl \
    cli\
    wget

RUN adduser -D -g 'www' www && \
    mkdir -p /var/www/html && \
    chown -R www:www /var/www/html

RUN mkdir -p /var/log/php82 && chown www:www /var/log/php82docker  

WORKDIR /var/www/html

RUN wget https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && \
    mv wordpress/* . && \
    rm -rf wordpress latest.tar.gz

COPY conf/www.conf /etc/php82/php-fpm.d/www.conf
COPY conf/wp-config.php /var/www/html/
RUN chown www:www /etc/php82/php-fpm.d/www.conf /var/www/html/wp-config.php

USER www

EXPOSE 9000

CMD [ "php-fpm82", "-F"]