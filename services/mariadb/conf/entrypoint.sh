#!/bin/sh
set -e

DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"
DB_PASSWORD="$(cat /run/secrets/db_password)"

DATADIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

mkdir -p /run/mysqld "$DATADIR"
chown -R mysql:mysql /run/mysqld "$DATADIR"

# Inicializar sistema de tablas si no existe
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

provision_with_root() {
  mariadb --protocol=socket --socket="$SOCKET" "$@" <<-EOSQL
    SET SESSION sql_log_bin=0;
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    ALTER  USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL
}

# 1) Intento sin password (root sin proteger)
if mariadb --protocol=socket --socket="$SOCKET" -u root -e "SELECT 1;" >/dev/null 2>&1; then
  echo ">>> Root sin password: fijando password y creando usuario"
  mariadb --protocol=socket --socket="$SOCKET" -u root <<-EOSQL
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
    FLUSH PRIVILEGES;
EOSQL
  provision_with_root -u root -p"${DB_ROOT_PASSWORD}"

# 2) Intento con password del secret
elif mariadb --protocol=socket --socket="$SOCKET" -u root -p"${DB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
  echo ">>> Root con password (coincide con secret): asegurando DB/usuario"
  provision_with_root -u root -p"${DB_ROOT_PASSWORD}"

# 3) Error: la password real no coincide con el secret
else
  echo "ERROR: No se puede autenticar como root con ni sin password."
  echo "Posible desajuste del secret vs. volumen. Ejecuta 'docker compose down -v' para reiniciar datos o corrige el secret."
  # Apagar temporal y salir con error
  mysqladmin --protocol=socket --socket="$SOCKET" -u root shutdown >/dev/null 2>&1 || true
  wait "$pid" || true
  exit 1
fi

echo ">>> Apagando temporal y arrancando en modo normal"
mysqladmin --protocol=socket --socket="$SOCKET" -u root -p"${DB_ROOT_PASSWORD}" shutdown || true
wait "$pid" || true

exec mysqld --user=mysql --datadir="$DATADIR" --socket="$SOCKET"