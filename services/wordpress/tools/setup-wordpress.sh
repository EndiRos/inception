#!/bin/sh
set -e

# Password solo desde secret
[ -f /run/secrets/db_password ] || { echo "Falta /run/secrets/db_password"; exit 1; }
DB_PASSWORD="$(cat /run/secrets/db_password)"

# Comprobar PHP/WP-CLI
php --version >/dev/null
wp --info >/dev/null

# Esperar a MariaDB con login real
echo ">>> Esperando a MariaDB..."
for i in $(seq 1 30); do
  if mysql -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
    echo ">>> MariaDB OK"
    break
  fi
  echo ">>> Intento $i/30..."
  sleep 2
  [ "$i" -eq 30 ] && { echo "ERROR: MariaDB no responde"; exit 1; }
done

cd /var/www/html

if wp core is-installed --path=/var/www/html >/dev/null 2>&1; then
  echo ">>> WordPress ya instalado"
  echo ${WORDPRESS_DB_USER}
  echo  ${DB_PASSWORD}
else
  echo ">>> Instalando WordPress..."
  DOMAIN="${DOMAIN_NAME:-localhost}"
  ADMIN_USER=${WORDPRESS_DB_USER}
  ADMIN_PASS=${DB_PASSWORD}
  ADMIN_MAIL="admin@${DOMAIN}"

  wp core install \
    --url="https://${DOMAIN}" \
    --title="Inception - 42 Project" \
    --admin_user="${ADMIN_USER}" \
    --admin_password="${ADMIN_PASS}" \
    --admin_email="${ADMIN_MAIL}" \
    --skip-email \
    --path=/var/www/html

  echo ">>> Admin: ${ADMIN_USER}  Pass: ${ADMIN_PASS}"
  wp theme activate twentytwentythree --path=/var/www/html || true
fi

# ---- Crear segundo usuario no admin (idempotente) ----
SECOND_USER="${WORDPRESS_SECOND_USER}"
SECOND_ROLE="${WORDPRESS_SECOND_ROLE:-subscriber}"

# Password estable opcional por env; si no, generar (solo se muestra al crear)
if [ -f /run/secrets/wp_credentials ]; then
  SECOND_PASS="$(tr -d '\r' </run/secrets/wp_credentials)"
else
  echo ">>> Secret wp_credentials no encontrado; generando password para segundo usuario"
  SECOND_PASS="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)"
fi

# Email (permite override)
SECOND_EMAIL="${WORDPRESS_SECOND_EMAIL:-${SECOND_USER}@${DOMAIN}}"
case "$SECOND_EMAIL" in
  *@*.*) : ;;
  *) SECOND_EMAIL="${SECOND_USER}@${DOMAIN}";;
esac

if wp user get "${SECOND_USER}" --path=/var/www/html >/dev/null 2>&1; then
  echo ">>> Usuario secundario '${SECOND_USER}' ya existe"
else
  echo ">>> Creando usuario secundario '${SECOND_USER}' (rol=${SECOND_ROLE})"
  wp user create "${SECOND_USER}" "${SECOND_USER}@${DOMAIN}" \
    --role="${SECOND_ROLE}" \
    --user_pass="${SECOND_PASS}" \
    --path=/var/www/html
  echo ">>> Segundo usuario: ${SECOND_USER}  Pass: ${SECOND_PASS}"
fi
exec php-fpm82 -F