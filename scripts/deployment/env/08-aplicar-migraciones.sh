#!/usr/bin/env bash
# scripts/deployment/env/08-aplicar-migraciones.sh
# Aplica las migraciones indicadas; sin argumentos, aplica V000, V001 y V003 en orden.
# Uso: 08-aplicar-migraciones.sh [V003__cuentas_esquema_sin_password ...]
set -euo pipefail
source scripts/deployment/env/00-config.sh
set -a; source config/.env; set +a
CONN="sys/$ORACLE_PWD@localhost:1521/$SERVICE_PDB"
if [ "$#" -gt 0 ]; then
MIGRACIONES=("$@")
else
MIGRACIONES=(V000__setup_entornos_negocio V001__create_esquemas_negocio V003__cuentas_esquema_sin_password)
fi
for MIG in "${MIGRACIONES[@]}"; do
MIG="${MIG%.sql}"
ARCHIVO="database/migrations/$MIG.sql"
if [ ! -f "$ARCHIVO" ]; then
echo "No existe la migración: $ARCHIVO"
exit 2
fi
echo ">> Aplicando $MIG"
LOG="$EVID/spool/$(ts)_08-$MIG.spool.log"
if ! docker exec -i "$CONT_NAME" sqlplus -s "$CONN" as sysdba \
< "$ARCHIVO" | tee "$LOG"; then
echo "ERROR en $MIG: revisa $LOG antes de continuar"
exit 1
fi
done
echo ">> Migraciones aplicadas. Evidencias en $EVID/spool/"
