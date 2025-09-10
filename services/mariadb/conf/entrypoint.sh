#!/bin/sh
set -e

DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"
DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"
MARKER="$DATADIR/.provisioned"

mkdir -p "$(dirname "$SOCKET")" "$DATADIR"
chown -R mysql:mysql "$(dirname "$SOCKET")" "$DATADIR"

# Inicializar sistema de tablas si falta
if [ ! -d "$DATADIR/mysql" ]; then
  echo ">>> Inicializando datos MariaDB"
  mariadb-install-db --user=mysql --datadir="$DATADIR" >/dev/null
fi

# Provisión inicial solo 1a vez (sin autenticación, usando --bootstrap)
if [ ! -f "$MARKER" ]; then
  echo ">>> Provisionando (bootstrap)"
  mysqld --user=mysql --datadir="$DATADIR" --skip-networking --socket="$SOCKET" --bootstrap <<-EOSQL
    SET SESSION sql_log_bin=0;
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    -- Asegurar root con password
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
    FLUSH PRIVILEGES;
EOSQL
  touch "$MARKER"
  chown mysql:mysql "$MARKER"
else
  echo ">>> DB ya provisionada, asegurando credenciales"
  # Intentar actualizar credenciales usando la pass del secret
  if ! mariadb -u root -p"${DB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
    echo ">>> ADVERTENCIA: la contraseña de root no coincide con el secret. Considera 'docker compose down -v'."
  else
    mariadb -u root -p"${DB_ROOT_PASSWORD}" <<-EOSQL
      CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
      CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
      ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
      GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
      FLUSH PRIVILEGES;
EOSQL
  fi
fi

echo ">>> Iniciando MariaDB"
exec mysqld --user=mysql --datadir="$DATADIR" --socket="$SOCKET"