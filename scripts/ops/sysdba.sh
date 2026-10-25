#!/usr/bin/env bash
# scripts/ops/sysdba.sh — ejecuta un archivo SQL como SYSDBA dentro del contenedor.
# Uso: bash scripts/ops/sysdba.sh <archivo.sql> [evidencia.log]
set -euo pipefail
source scripts/deployment/env/00-config.sh
SQLFILE="${1:?Uso: sysdba.sh <archivo.sql> [evidencia.log]}"
LOG="${2:-}"
[ -f "$SQLFILE" ] || { echo "No existe el archivo SQL: $SQLFILE"; exit 2; }
NLS_LANG="${NLS_LANG:-AMERICAN_AMERICA.AL32UTF8}"
sysdba() { docker exec -e NLS_LANG="$NLS_LANG" -i "$CONT_NAME" sqlplus -s -L / as sysdba < "$SQLFILE"; }
if [ -n "$LOG" ]; then
mkdir -p "$(dirname "$LOG")"
sysdba | tee "$LOG"
else
sysdba
fi
