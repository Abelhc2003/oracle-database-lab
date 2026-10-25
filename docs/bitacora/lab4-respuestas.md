Preguntas tipo examen

P1 — A y D. Tras SHUTDOWN IMMEDIATE todos los datafiles quedan con el mismo SCN de checkpoint, así que la copia es consistente y se abre con un STARTUP normal, sin redo ni RMAN (es lo que hace mi backup-estado.sh).

P2 — B. En Standard Edition no existe MOVE DATAFILE online (igual que en Free, ORA-00439), así que toca OFFLINE, copiar, RENAME y ONLINE, que es justo lo que hace mi 03-reubicar-datafiles.sh.

P3 — A y C. STARTUP_TIME es de la instancia y cambia en cada arranque; CREATED es de la base y no cambia. El DBID identifica la base, así que sigue igual aunque recree el contenedor.

P4 — A y C. En NOMOUNT ya hay SGA y parámetros cargados (v$parameter me respondía en el 06) y es la etapa para CREATE CONTROLFILE. dba_users necesita OPEN; ARCHIVELOG y renombrar SYSTEM necesitan MOUNT.

P5 — B. El modo ARCHIVELOG se guarda en el control file, así que tiene que estar abierto (MOUNT), pero con los datafiles todavía cerrados.

P6 — B. Si la instancia arrancó con SPFILE, el SCOPE por defecto es BOTH.

P7 — C. PROCESSES es un parámetro de instancia (ISPDB_MODIFIABLE = FALSE). Desde FREEPDB1 salta ORA-65040, como en el bloque 5 de 07-parametros-cambios.

P8 — A y C. Primero arranco con un PFILE bueno y luego regenero el SPFILE con CREATE SPFILE FROM PFILE. Las otras opciones no arreglan el archivo.

P9 — B. Con MEMORY_TARGET = 0 y SGA_TARGET > 0 es ASMM, y un DB_CACHE_SIZE fijado actúa como mínimo, no como tamaño fijo.

P10 — A y D. Con servidor dedicado, las work areas (sort) y la memoria de sesión van en la PGA. Shared pool, log buffer y buffer cache son SGA.

P11 — C. El COMMIT no vuelve hasta que LGWR escribe el redo en los online redo logs. DBWn escribe los bloques más tarde.

P12 — B y D. PMON y SMON están en cualquier instancia. ARC0 solo existe en ARCHIVELOG y CJQ0 solo con jobs. La C está mal planteada porque RECO arranca siempre, no "solo si hay database links".


Preguntas de comprobación
(La evidencia está en docs/bitacora/lab4/evidencia/)

8.1.1 Respaldo

1. Es consistente porque la hice en frío: backup-estado.sh hace SHUTDOWN IMMEDIATE antes de copiar, así que todos los datafiles quedan con el mismo SCN de checkpoint y al restaurar no hace falta aplicar redo. Si la copiara con la base abierta, los archivos tendrían SCN distintos y la copia sería inconsistente: no se podría abrir sin recuperación (necesitaría ARCHIVELOG y RMAN). Evidencia: 00-backup-lab3 (Database closed / ORACLE instance shut down antes del tar).

2. manifiesto.txt dice qué es la copia: etiqueta, fecha, contenedor, volumen, imagen y commit. SHA256SUMS guarda la huella de cada archivo para comprobar que nada se ha corrompido ni falta. restaurar-estado.sh lo primero que hace es sha256sum --check; si falla, se para sin tocar el volumen. Además te pide escribir el nombre del volumen para confirmar.

3. RPO: lo que perdería si restauro es todo lo hecho después de la copia (2026-10-22T15:54:53Z, SCN 3435354). RTO: lo que tardo en volver a dar servicio, que es descomprimir unos 712 MB y esperar a que la base esté abierta. Lo estimo en unos 2 minutos, no lo he cronometrado; lo mediremos en el Lab 5. Evidencia: manifiesto.txt, inventario.txt y 00-backup-lab3.

8.1.2 Diagnóstico y correcciones

4. V000 creó los datafiles con ruta relativa ('academia01.dbf') y Oracle los puso en $ORACLE_HOME/dbs, que es su directorio por defecto. En mi imagen esa carpeta es un enlace a dbconfig/FREE/dbs, así que estaban dentro del volumen, pero en un sitio que nadie esperaría. DB_CREATE_FILE_DEST lo habría evitado solo si V000 no hubiera puesto nombre de archivo (OMF); con un nombre relativo los sigue mandando a dbs. Lo correcto es poner la ruta absoluta. Evidencia: 01-diagnostico (db_create_file_dest vacío y rutas en dbs).

5. Porque RENAME DATAFILE solo cambia la ruta que tiene guardada el control file; no mueve el archivo. Si no lo copias antes, Oracle busca un archivo que no existe. Por eso 03-reubicar hace OFFLINE, cp -p, RENAME, ONLINE y solo al final borra el original.

6. V000 ya está aplicada, y si la edito el repositorio deja de reflejar lo que se ejecutó de verdad en la base (forward-only migrations). Por eso la corrección va en una migración nueva, V003. Y borrar la contraseña del archivo no sirve porque sigue en el historial de Git. Con NO AUTHENTICATION la contraseña deja de funcionar, que es lo que protege de verdad. Lo comprobé: entrar como admin_academia con la contraseña antigua da ORA-01017.

7. Demuestra que la base vive en el volumen y no en el contenedor: borré el contenedor, lo recreé con el 05 v2 y los tablespaces y los datos seguían ahí. Se hace después de reubicar porque, si algún datafile hubiera estado fuera del volumen, el docker rm lo habría borrado. Evidencia: 03-prueba-persistencia (antes y después iguales; 8181 ya no aparece en docker port).

8.1.3 Instancia y arranque

8. De la instancia: arrancada el 2026-10-22 a las 16:25:37 (05-instancia-y-base), SGA de 1603398928 bytes (06-arranque) y 88 procesos Oracle en 55 procesos Linux (09-procesos). Todo esto desaparece al parar. De la base de datos: DBID 1509902213, creada el 2026-07-05 (05-instancia-y-base), y 16 datafiles más 2 control files en disco. Esto sigue ahí aunque la instancia esté parada.

9. En NOMOUNT lee el SPFILE, reserva la SGA y arranca los procesos. Todavía no ha abierto el control file, por eso v$database da ORA-01507 pero v$parameter sí responde. En MOUNT abre el control file y ya conoce los datafiles, pero no los abre. El diccionario vive en SYSTEM, así que dba_tables da ORA-01219. En OPEN abre datafiles y redo y ya funciona todo. Evidencia: 06-arranque-por-etapas.

10. Porque FREEPDB1 tiene el estado guardado con SAVE STATE (sale en dba_pdb_saved_states). Si no se abriera, haría ALTER PLUGGABLE DATABASE FREEPDB1 OPEN; y después ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE; para que no vuelva a pasar.

11. ORA-00800 es ruido conocido: Oracle intenta subir la prioridad de VKTM/LGWR y el contenedor no le deja (falta CAP_SYS_NICE), pero la base arranca bien justo después (06-alert-log). ORA-20013 no me ha salido. Si apareciera también sería ruido: es DBMS_QOPATCH, que no puede leer el inventario de parches dentro de un contenedor. Los documentaría como conocidos y cualquier otro ORA- lo investigaría.

8.1.4 Parámetros

12. v$parameter es el valor que está usando la instancia ahora, en memoria. v$spparameter es lo que está escrito en el SPFILE. Con db_files: vale 200 por defecto y no está en el SPFILE. Al poner 300 con SCOPE=SPFILE, v$parameter seguía en 200 y v$spparameter en 300, pendiente del próximo arranque. Con RESET volvió a "no especificado". Evidencia: 07-parametros-cambios.

13. SCOPE=BOTH cambia el valor en memoria y en el SPFILE a la vez, así que se aplica ya y aguanta el reinicio: con open_cursors = 500 salía 500 en los dos sitios (07-parametros-cambios). Si la instancia arrancó con SPFILE, el SCOPE por defecto es BOTH (con PFILE sería MEMORY).

14. Porque PROCESSES dimensiona estructuras de la SGA que se reservan al arrancar, así que en la práctica es estático aunque v$parameter diga IMMEDIATE. Al intentarlo con SCOPE=MEMORY me dio ORA-02097 / ORA-02095. Se cambia con SCOPE=SPFILE y reiniciando. Evidencia: 07-parametros-lectura (IMMEDIATE) y 07-parametros-cambios (ORA-02095).

15. El PFILE es el SPFILE en texto. Versionarlo deja una foto de la configuración en Git que puedo comparar con git diff, y me sirve para arrancar si un día rompo el SPFILE. Configuration drift es cuando la configuración real cambia sin que nadie lo documente; con PFILEs versionados se detecta comparando los de distintos días. Aparte, el PFILE de memoria tiene 122 líneas y el del SPFILE 32, porque el primero incluye también los valores derivados y por defecto.

8.1.5 Memoria y procesos

16. ASMM: memory_target = 0 y memory_size = 0 (sin AMM), sga_target = 1536M (Oracle reparte la SGA solo) y la PGA va aparte con pga_aggregate_target = 512M. Evidencia: 08-memoria.

17. Ronda 1 (caché fría): 247 lecturas lógicas y 245 físicas, una tasa de acierto de casi 0 (1 - 245/247 ≈ 0,8 %). Ronda 2 (caché caliente): 247 lógicas y 0 físicas, 100 % de acierto. Las lógicas son iguales en las dos rondas porque toda lectura física acaba en una lógica: el bloque se trae a la caché y se lee desde ahí. Salen 245 físicas para una tabla de 244 bloques porque se lee también la cabecera del segmento. Al final había 245 bloques de la tabla en v$bh. Evidencia: 08-experimento-cache.

18. Porque casi todo el RSS de cada proceso es la SGA, que es compartida y aparece repetida en todos. Si sumo el RSS de los 50 y pico procesos me salen varios GB, cuando el contenedor entero usa unos 1,4 GiB (05-instancia-so). Para la memoria real miro v$sga más v$pgastat, o docker stats.

19. El SPID de LGWR en v$process es 31335 y en /proc dentro del contenedor sale el mismo PID con db_lgwr_FREE (09-procesos y 09-procesos-so). Con docker top el mismo LGWR sale como 925197, porque docker top muestra el PID del anfitrión y el contenedor tiene su propio espacio de nombres de PID (09-docker-top). Por cierto, la primera vez el 05 me salía raro (la ayuda de docker y un error del top de Linux) porque al copiar del PDF se habían partido líneas del script.

20. PMON limpia los procesos que mueren: deshace su transacción y libera sus bloqueos. Por ejemplo, si se cae un portátil a mitad de un UPDATE, PMON hace el rollback y suelta las filas. SMON hace la recuperación de la instancia al arrancar y limpia segmentos temporales. Por ejemplo, después de un SHUTDOWN ABORT, SMON aplica el redo al abrir (en el alert log se ve el "Crash Recovery").

8.1.6 Seguridad y trabajo profesional

21. Porque para mirar no hace falta poder romper (least privilege). SYSTEM puede cambiarlo todo, y un error en una consulta o en un script de monitorización podría hacer daño. C##OPS_RO solo tiene CREATE SESSION, SET CONTAINER y SELECT_CATALOG_ROLE, más el atributo CONTAINER_DATA = ALL para ver todas las PDB. No puede modificar datos, crear objetos o usuarios, cambiar parámetros ni parar la base.

22. Una: las contraseñas de los admin_* escritas en V000, que estaban en Git; V003 las invalida con NO AUTHENTICATION. Dos: sys/<contraseña> en la línea de comandos del 08, que se veía con ps -ef; ahora se usa / as sysdba con autenticación del SO. Además, el 05 v2 ya no pasa ORACLE_PWD al contenedor cuando reutiliza el volumen.
