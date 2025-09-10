#!/bin/sh
set -e

# Secrets
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"
MARKER="$DATADIR/.provisioned"

mkdir -p "$(dirname "$SOCKET")" "$DATADIR"
chown -R mysql:mysql "$(dirname "$SOCKET")" "$DATADIR"

# Inicializar tablas si no existen
if [ ! -d "$DATADIR/mysql" ]; then
  echo ">>> Inicializando datos MariaDB"
  mariadb-install-db --user=mysql --datadir="$DATADIR" >/dev/null
fi

echo ">>> Arranque temporal (skip-networking)"
mysqld --user=mysql --datadir="$DATADIR" --socket="$SOCKET" --skip-networking &
pid="$!"

# Esperar socket
for i in $(seq 1 30); do
  if mysqladmin --protocol=socket --socket="$SOCKET" ping >/dev/null 2>&1; then break; fi
  echo ">>> Esperando MariaDB ($i/30)..."; sleep 1
done
mysqladmin --protocol=socket --socket="$SOCKET" ping >/dev/null 2>&1 || { echo "ERROR: MariaDB no inició"; exit 1; }

if [ ! -f "$MARKER" ]; then
  echo ">>> Provisionando inicial (sin password de root)"
  mariadb --protocol=socket --socket="$SOCKET" -u root <<-EOSQL
    SET SESSION sql_log_bin=0;
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
    FLUSH PRIVILEGES;
EOSQL
  touch "$MARKER"
  chown mysql:mysql "$MARKER"
else
  echo ">>> Asegurando credenciales (con password de root)"
  if mariadb --protocol=socket --socket="$SOCKET" -u root -p"${DB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
    mariadb --protocol=socket --socket="$SOCKET" -u root -p"${DB_ROOT_PASSWORD}" <<-EOSQL
      CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
      CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
      ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
      GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
      FLUSH PRIVILEGES;
EOSQL
  else
    echo ">>> ADVERTENCIA: la contraseña de root no coincide con el secret. Considera 'docker compose down -v'."
  fi
fi

echo ">>> Apagando temporal y arrancando en modo normal"
# Apagar temporal con la pass ya establecida
mysqladmin --protocol=socket --socket="$SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown || true
wait "$pid" || true

exec mysqld --user=mysql --datadir="$DATADIR" --socket="$SOCKET"