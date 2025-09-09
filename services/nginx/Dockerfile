FROM alpine:3.18

WORKDIR /app

RUN apk update && apk add --no-cache bash vim nginx

# Crear todas las rutas necesarias antes de chown
RUN mkdir -p /var/www/html \
    /var/lib/nginx \
    /run/nginx \
    /var/log/nginx

# Usuario consistente con nginx.conf
RUN adduser -D -g 'enetxeba' enetxeba && \
    chown -R enetxeba:enetxeba /var/www/html /var/lib/nginx /var/log/nginx /run/nginx

# Config principal (sin server block)
COPY conf/nginx.conf /etc/nginx/
# Server block separado
COPY conf/default.conf /etc/nginx/conf.d/
# (index solo como placeholder; WordPress sobrescribirá vía volumen)
COPY html/index.html /var/www/html/

COPY ssl/enetxeba.crt /etc/nginx/ssl/
COPY ssl/enetxeba.key /etc/nginx/ssl/

EXPOSE 443
CMD ["nginx", "-g", "daemon off;"]