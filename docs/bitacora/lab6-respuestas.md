# Respuestas Lab 6 · E032

## Preguntas de comprobación

1: En la lista de turno salieron 7 errores ORA- en 24 h (evidencia 01-turno). Casi todos son de los arranques de hoy, sobre todo el ORA-00800 "Set Priority Failed", que sale cada vez que arranca la base en el contenedor. El número solo no dice nada, hay que compararlo con la línea base de otros días.

2: La ventana del miércoles (WEDNESDAY_WINDOW) empieza a las 22:00 y dura 4 horas (spool 01-automatizacion). En ella corren las tres tareas de AutoTask: auto optimizer stats collection, auto space advisor y sql tuning advisor.

3: Después del SCOPE = SPFILE, V$SPPARAMETER (el archivo) tenía db_files = 250 con ISSPECIFIED TRUE y V$PARAMETER (la memoria) seguía en 200 (evidencia 02-parametros). Sin el RESET, en el siguiente reinicio la base habría arrancado con db_files = 250.

4: Porque db_files no estaba fijado antes: en mi copia init_desde_spfile.ora (34 líneas) no aparece, así que RESET lo deja como estaba. processes sí estaba fijado (línea *.processes=200), y un RESET lo habría devuelto al valor por defecto, no a 200. Para processes habría que volver a poner 200 a mano.

5: C##OPS_RO recibió ORA-01109: database not open (evidencia 02-estados-pdb). La instancia decía "Database opened" porque el CDB sí se abrió, pero FREEPDB1 se quedó en MOUNTED al no tener estado guardado.

6: La sesión de la aplicación tenía SID 67, SPID 2703 y el evento PL/SQL lock timer (evidencia 03-sesiones). MODULE (matriculas), ACTION (cierre-periodo) y CLIENT_IDENTIFIER (ana.garcia@ucam) dicen qué está haciendo y para quién. Con USERNAME solo sabría que es APP_ACADEMIA, que es la misma cuenta para todas las sesiones de la aplicación.

7: Tras el CANCEL SQL seguía habiendo 1 transacción abierta. Tras el KILL SESSION ya no quedaban sesiones de la aplicación (0), así que tampoco transacciones. La fila 101 quedó en ACTIVO porque al matar la sesión su UPDATE sin confirmar se deshizo (evidencia 03-sesiones).

8: En mi imagen common_user_prefix vale C## (evidencia 03-cuenta-app). Eso quiere decir que una cuenta común tiene que empezar por C##, como C##OPS_RO.

9: Mis cifras (evidencia 04-tres-miradas):
- ALL_TABLES de ADMIN_ACADEMIA: raíz 0, FREEPDB1 0, APP_ACADEMIA 1.
- DBA_USERS: raíz 37, FREEPDB1 47, APP_ACADEMIA ORA-00942.
- CDB_USERS: raíz ve el contenedor 1 (37) y el 3 (47); en FREEPDB1 solo el 3 (47); APP_ACADEMIA ORA-00942.
- V$DATAFILE: raíz 17, FREEPDB1 10, APP_ACADEMIA ORA-00942.
Una diferencia: C##OPS_RO desde la raíz ve los usuarios de los dos contenedores en CDB_USERS por tener CONTAINER_DATA = ALL, pero dentro de FREEPDB1 solo ve los de esa PDB.

10: Salieron 5367 lecturas lógicas por recorrido y la carga costó 0,28 s de DB time y 0,26 s de DB CPU (evidencia 04-deltas). Como DB time es casi igual a DB CPU, casi todo fue trabajo de CPU y la carga no tuvo que esperar a nada.

11: Antes de la carga, TBS_ACADEMIA_HIST tenía 10 MB asignados, 3,9 MB libres y un máximo de 40 MB (evidencia 05-almacenamiento). Para alertar usaría el porcentaje sobre el máximo (15,16 %), porque el tablespace puede crecer hasta 40 MB y lo que importa es cuánto le queda hasta ese techo.

12: Insertó SYS, pero el segmento iba a ser de CARGA_HIST, y la cuota la paga el dueño del segmento, que no tenía (ORA-01950). En el ORA-01536 el tablespace tenía sitio de sobra; lo que faltaba era cuota de CARGA_HIST (solo 2 MB), así que ampliar el tablespace no lo arreglaba.

13: La carga se suspendió a las 18:51:33 y terminó a las 18:51:48, así que estuvo parada unos 12-14 segundos, hasta que subí la cuota a 30 MB (evidencia 05-resumable). En el alert log quedaron dos líneas: "statement in resumable session 'carga-historico' was suspended" y "... was resumed".

14: Antes del DELETE: 20000 filas, 2944 bloques y 23 MB. Después del DELETE: 2000 filas, pero los mismos 2944 bloques y 23 MB. Después del SHRINK: 2000 filas, 304 bloques y 2,4 MB, y la cuota usada bajó a 2,4 MB (evidencia 05-hwm-shrink). El DELETE no devuelve espacio porque no baja la HWM: los bloques siguen asignados a la tabla aunque estén casi vacíos.

15: Mi perfil DEFAULT tenía FAILED_LOGIN_ATTEMPTS 10, PASSWORD_LIFE_TIME 180, PASSWORD_LOCK_TIME 1, PASSWORD_GRACE_TIME 7, INACTIVE_ACCOUNT_TIME 365 y PASSWORD_VERIFY_FUNCTION NULL (evidencia 06-gobierno-acceso). En PRF_PERSONAS, FAILED_LOGIN_ATTEMPTS 3 hace que si alguien prueba contraseñas la cuenta se bloquee enseguida, y PASSWORD_VERIFY_FUNCTION obliga a usar contraseñas fuertes en vez de cosas como "corta".

16: Porque su rol de secretaría incluye ROL_LECTURA_ACADEMIA, que tiene SELECT ANY TABLE ON SCHEMA admin_academia, y eso deja leer todas las tablas del esquema, también ACA_MATRICULAS (60000 filas). Al cambiar el nombre de un alumno le salió ORA-41900, falta el privilegio UPDATE, porque solo puede cambiar la columna ESTADO (evidencia 06-probar-acceso).

17: Con la columna nueva (telefono) no se invalidó nada, porque ningún objeto la usa y Oracle controla las dependencias por columna. Al ampliar email_institucional se invalidó V_CONTACTO_LAB6. Al ampliar nombres se invalidaron V_ACTIVOS_LAB6 y, en cascada, F_TOTAL_ACTIVOS_LAB6, que depende de esa vista (evidencia 07-objetos).

18: No. En el advisor de SGA, con factor 2 (3072 MB) el ESTD_DB_TIME_FACTOR sigue en 1, así que no se ganaría nada. En el de PGA salen sobreasignaciones (2) con 256 MB y 128 MB, así que por debajo de unos 384 MB ya las habría (evidencia 07-memoria).

19: La consulta necesitó 247 lecturas lógicas. Lo dice la línea FETCH de la traza (cr=247), y en tkprof sale en la columna query de la fila Fetch (evidencia 07-adr-trazas).

20:
- INC-601: evidencia: Ana (SID 204) en "enq: TX - row lock contention", bloqueada por la SID 220 de APP_ACADEMIA con 1 registro sin confirmar. Intervención: ALTER SYSTEM KILL SESSION '220,2132' IMMEDIATE. Validación: la fila 101 en ACTIVO y nadie esperando en el diagnóstico.
- INC-602: evidencia: academia_app en NO en la sección 6 del diagnóstico, con la base abierta. Intervención: DBMS_SERVICE.START_SERVICE('academia_app') y SAVE STATE. Validación: lsnrctl lo vuelve a mostrar y app.sh conecta.
- INC-603: evidencia: APP_ACADEMIA en LOCKED (no TIMED) con perfil de 10 intentos. Intervención: ALTER USER app_academia ACCOUNT UNLOCK. Validación: app.sh entra y la sección 7 sale vacía.

## Simulacro 1Z0-182

S1: B. Las alertas de espacio las genera MMON (Parte B, umbrales).
S2: C. DEFERRED solo vale para las sesiones nuevas (Parte C).
S3: B. FROM MEMORY guarda todo lo que está en uso, también lo calculado (Parte C).
S4: B y C. FORCE la cierra y la abre en un paso; si no, se cierra y se abre (Parte C).
S5: C. DBA_PDB_SAVED_STATES (Parte C).
S6: B. ORA-01035, como le pasó a C##OPS_RO (Parte C).
S7: A. DBMS_SERVICE, con el que creé academia_app (Parte D).
S8: B. PADDR = ADDR (Parte D).
S9: C. CANCEL SQL corta la llamada pero la transacción sigue abierta (Parte D).
S10: C. SYSOPER sale como PUBLIC (Parte D).
S11: B. V$CON_SYSMETRIC; V$SYSMETRIC es de la instancia (Parte E).
S12: A y C. CPU más esperas no Idle de primer plano (Parte E).
S13: B. La cuota la necesita HR, el dueño de la tabla (Parte F).
S14: A y C. Undo y temporal dan ORA-30041 (Parte F).
S15: A y C. Se suspende y se ve en DBA_RESUMABLE (Parte F).
S16: B. ROW MOVEMENT y ASSM (Parte F).
S17: B. LOCKED(TIMED), como le pasó a Ana (Parte G).
S18: B. Con ADMIN OPTION no hay cascada (Parte G).
S19: A y B. MOVE sin UPDATE INDEXES y ALTER INDEX UNUSABLE (Parte H).
S20: B. DBMS_MONITOR.SESSION_TRACE_ENABLE (Parte H).
S21: C. DIAGNOSTIC_DEST (Parte H).
S22: C. Primero identificar al bloqueador y qué está haciendo (Parte I).
