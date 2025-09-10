#!/bin/sh
set -e

# Esperar a que MariaDB esté disponible
echo ">>> Esperando a que MariaDB esté disponible..."
while ! mysqladmin ping -h"${WORDPRESS_DB_HOST}" --silent; do
    echo ">>> MariaDB aún no está disponible. Esperando 5 segundos..."
    sleep 5
done
echo ">>> MariaDB está disponible"

# Obtener la contraseña de la BD desde el secret
DB_PASSWORD=$(cat /run/secrets/db_password)

# Modificar wp-config.php para usar la contraseña del secret
sed -i "s/define('DB_PASSWORD',.*/define('DB_PASSWORD', '$DB_PASSWORD');/" wp-config.php

# Verificar si WordPress ya está instalado
wp core is-installed 2>/dev/null
if [ $? -eq 0 ]; then
    echo ">>> WordPress ya está instalado, omitiendo configuración"
else
    echo ">>> Instalando WordPress..."
    
    # Instalar WordPress usando el password desde secret
    wp core install \
        --url=https://${DOMAIN_NAME} \
        --title="Inception - 42 Project" \
        --admin_user=${WORDPRESS_DB_USER} \
        --admin_password="${DB_PASSWORD}" \
        --admin_email=admin@${DOMAIN_NAME} \
        --path=/var/www/html \
        --skip-email
    
    # Crear usuario adicional también con el password desde secret
    wp user create enetxeba enetxeba@${DOMAIN_NAME} \
        --role=author \
        --user_pass="${DB_PASSWORD}" \
        --path=/var/www/html
    
    # Activar tema y plugins
    wp theme activate twentytwentythree --path=/var/www/html
    
    # Crear contenido de ejemplo
    wp post create \
        --post_type=page \
        --post_title="Bienvenido a Inception" \
        --post_content="Esta es una página creada automáticamente para el proyecto Inception de 42." \
        --post_status=publish \
        --path=/var/www/html
        
    echo ">>> WordPress configurado correctamente"
fi

# Continuar con la ejecución normal de PHP-FPM
echo ">>> Iniciando PHP-FPM..."
exec php-fpm82 -F