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
    bash \
    mariadb-client \
    wget

# Instalar WP-CLI
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

RUN adduser -D -g 'www' www && \
    mkdir -p /var/www/html && \
    chown -R www:www /var/www/html

RUN mkdir -p /var/log/php82 && chown www:www /var/log/php82 

RUN ln -sf /usr/bin/php82 /usr/bin/php

WORKDIR /var/www/html

RUN wget https://wordpress.org/latest.tar.gz && \
    tar -xzf latest.tar.gz && \
    mv wordpress/* . && \
    rm -rf wordpress latest.tar.gz

COPY conf/www.conf /etc/php82/php-fpm.d/www.conf
COPY conf/wp-config.php /var/www/html/
COPY tools/setup-wordpress.sh /usr/local/bin/setup-wordpress.sh
RUN chmod +x /usr/local/bin/setup-wordpress.sh && \
    chown www:www /etc/php82/php-fpm.d/www.conf /var/www/html/wp-config.php

USER www

EXPOSE 9000

CMD ["/bin/sh", "-c", "/usr/local/bin/setup-wordpress.sh && php-fpm82 -F"]