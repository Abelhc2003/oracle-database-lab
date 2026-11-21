# Runbook: pérdida de un datafile (tablespace de negocio)

## Síntomas
Una consulta falla con ORA-01116 (no puede abrir el archivo n), ORA-01110 (qué archivo es) y ORA-27041 (el sistema operativo no lo encuentra). En el alert log puede salir también ORA-63999: Oracle ha cerrado la PDB para protegerla.

## Comprobaciones previas
1. ¿La base está en ARCHIVELOG? `SELECT log_mode FROM v$database;` Si no lo está, solo queda restaurar la última copia en frío y se pierde lo posterior.
2. ¿Hay copia del archivo? En RMAN: `LIST BACKUP OF DATAFILE n;`
3. ¿En qué estado está la PDB? `SELECT name, open_mode FROM v$pdbs;`

## Camino 1: la PDB sigue abierta (READ WRITE)
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE n OFFLINE;
En RMAN: RESTORE DATAFILE n; y RECOVER DATAFILE n;
ALTER DATABASE DATAFILE n ONLINE;

Solo ese tablespace deja de estar disponible; el resto de la PDB sigue dando servicio.

## Camino 2: Oracle ha cerrado la PDB (MOUNTED, ORA-63999)
1. Esperar a que v$pdbs diga MOUNTED. No lanzar RMAN mientras se está cerrando, porque falla con ORA-01089.
2. En RMAN: RESTORE DATAFILE n; y RECOVER DATAFILE n;
3. ALTER SESSION SET CONTAINER = FREEPDB1; ALTER DATABASE DATAFILE n ONLINE;
4. ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;

## Cómo comprobar que ha funcionado
- v$pdbs dice READ WRITE.
- Una fila cambiada después de la copia sigue con su valor nuevo (en el simulacro, la 104 seguía como EGRESADO). Eso confirma RPO 0.
- No se da el incidente por cerrado hasta ver las dos cosas.

## A quién avisar
Al responsable de la base o al profesor, con la hora del fallo, el archivo afectado, el camino que se siguió y el RTO medido (en mi simulacro, 11 s).
