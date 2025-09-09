#!/bin/sh
set -e

# Inicialización MariaDB
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo ">>> Inicializando directorio de datos de MariaDB"
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Verificar si el directorio está vacío (primera ejecución)
if [ ! -d "/var/lib/mysql/inception" ]; then
    echo ">>> Configurando MariaDB en primer arranque"
    
    # Iniciar MariaDB en modo temporal para configuración
    mysqld --user=mysql --skip-networking &
    pid="$!"
    
    # Esperar hasta que el servidor esté disponible
    echo ">>> Esperando inicio de MariaDB..."
    for i in {1..30}; do
        if mysqladmin ping >/dev/null 2>&1; then
            break
        fi
        echo ">>> Esperando MariaDB ($i/30)..."
        sleep 1
    done
    
    # Si no inicia después de 30s, abortar
    if ! mysqladmin ping >/dev/null 2>&1; then
        echo ">>> ERROR: MariaDB no inició en 30s"
        exit 1
    fi
    
    echo ">>> Creando usuario y base de datos"
    # Crear base de datos y usuario
    mysql -u root <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
        GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        FLUSH PRIVILEGES;
EOSQL
    
    # Apagar el servidor temporal
    echo ">>> Completada la configuración inicial"
    mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} shutdown
    
    # Esperar a que termine
    wait "$pid"
    echo ">>> MariaDB configurado exitosamente"
fi

# Iniciar MariaDB en modo normal
echo ">>> Iniciando MariaDB"
exec mysqld --user=mysql