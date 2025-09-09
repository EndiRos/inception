FROM alpine:3.18

RUN apk update && apk add --no-cache \
    mariadb mariadb-client mariadb-server-utils

RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY conf/my_conf.cnf /etc/my.cnf.d/my_conf.cnf
COPY conf/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3306
ENTRYPOINT ["/entrypoint.sh"]