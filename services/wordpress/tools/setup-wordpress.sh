#!/bin/sh
set -e

# Obtener contraseñas desde secrets
DB_PASSWORD=$(cat /run/secrets/db_password)

# Esperar a que MariaDB esté disponible
echo ">>> Esperando a que MariaDB esté disponible..."
COUNTER=0
MAX_TRIES=30

until mysqladmin ping -h"${WORDPRESS_DB_HOST}" -u"${WORDPRESS_DB_USER}" -p"${DB_PASSWORD}" --silent || [ $COUNTER -eq $MAX_TRIES ]; do
    echo ">>> Intento $COUNTER de $MAX_TRIES. MariaDB aún no está disponible..."
    sleep 5
    COUNTER=$((COUNTER+1))
done

if [ $COUNTER -eq $MAX_TRIES ]; then
    echo ">>> ERROR: MariaDB no respondió después de $MAX_TRIES intentos"
    exit 1
fi

echo ">>> MariaDB está disponible"

# Resto del script...
exec php-fpm82 -F