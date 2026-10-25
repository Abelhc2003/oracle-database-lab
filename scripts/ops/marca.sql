-- scripts/ops/marca — define &marca con la fecha/hora UTC para nombrar la evidencia.
SET FEEDBACK OFF
COLUMN marca NEW_VALUE marca NOPRINT
SELECT TO_CHAR(SYS_EXTRACT_UTC(SYSTIMESTAMP), 'YYYYMMDD"T"HH24MISS"Z"') AS marca FROM dual;
SET HEADING ON
