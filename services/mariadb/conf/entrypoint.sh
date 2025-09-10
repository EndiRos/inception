#!/bin/sh
set -e

DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

# Asegurar directorios y permisos
mkdir -p /var/run/mysqld
chown -R mysql:mysql /var/run/mysqld /var/lib/mysql

# Inicialización si no existe el sistema de tablas
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo ">>> Inicializando directorio de datos de MariaDB"
  mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Arranque temporal para configurar
echo ">>> Arrancando MariaDB temporalmente para configurar"
mysqld --user=mysql --skip-networking &
pid="$!"

# Esperar a que el socket esté listo
for i in $(seq 1 30); do
  if mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
    break
  fi
  echo ">>> Esperando MariaDB ($i/30)..."
  sleep 1
done

if ! mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
  echo ">>> ERROR: MariaDB no inició en 30s"
  exit 1
fi

# Si es primer arranque de tu DB de proyecto, crear DB/usuario
echo ">>> Creando/asegurando base de datos y usuario"
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -u root <<-EOSQL
  CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
  CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
  ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
  GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
  FLUSH PRIVILEGES;
EOSQL

echo ">>> Configuración inicial completa. Apagando arranque temporal"
mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -u root -p"${DB_ROOT_PASSWORD}" shutdown || true
wait "$pid" || true

echo ">>> Iniciando MariaDB en modo normal"
exec mysqld --user=mysql