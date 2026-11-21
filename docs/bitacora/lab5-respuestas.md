1. Preguntas para comprobar
1: En la copia del Lab 3 salían cinco datafiles fuera del volumen (los de los tablespaces de negocio). En la del Lab 4 sale "ninguno: el volumen contiene toda la base de datos" (00-backup-lab4). Eso demuestra que la reubicación de datafiles del Lab 4 funcionó: ahora toda la base está dentro del volumen y la copia la recoge entera.

2: CLIENTE: 100 000 filas / 1517 bloques = 66 filas por bloque. PEDIDO: 1 000 000 / 5320 = 188 (01-perfil-tiendasur). PEDIDO mete casi el triple porque sus filas ocupan 32 bytes de media y las de CLIENTE 102: si la fila es tres veces más corta, caben unas tres veces más en el mismo bloque de 8 KB.

3: Porque la primera vez incluye trabajo que solo se hace una vez: analizar la sentencia, subir bloques a la caché y la limpieza diferida de bloques tras la carga. La segunda ya va "en caliente" y da el coste real de la consulta. En la prueba de la PK sale lo esperado, 4 lecturas lógicas (01-herramienta-medir).

Anatomía y tipos de índice (C, D)

4: Altura 3, 2216 hojas y 6 ramas. El factor de ramificación real es (2216 + 6 − 1) / 6 = 370 y el máximo 543 (02-anatomia-indice). Con mil millones de filas tendría unas 2 208 969 hojas y altura 4, o sea 5 lecturas para encontrar una fila. Como crece con el logaritmo, multiplicar las filas por mil solo añade un nivel.

5: La primera entrada es row#0 ... data:(6): 00 00 03 1b 00 00 con clave c1 02 (el número 1). Los 4 primeros bytes son el bloque, 0x31B = 795, y los 2 últimos la ranura, 0. La consulta de comprobación lo confirma: el cliente 1 está en el bloque 795, ranura 0 (02-anatomia-indice). No aparece el número de archivo porque TBS_TIENDASUR es bigfile: solo tiene un datafile, así que basta con bloque y ranura.

6: Elijo estas tres (03-tipos-indice):

Único (Q13): buscar por DNI pasa de 1486 lecturas (recorrido completo) a 3. Además impide duplicados: el INSERT con un DNI repetido da ORA-00001.
Compuesto y cubriente (Q7): con el índice simple son 15 lecturas y un SORT; con (id_cliente, fecha) bajan a 7, sin ordenar, porque el índice ya devuelve las filas en orden; con el cubriente, 3, porque ni siquiera va a la tabla.
Bitmap (Q14): con cuatro filtros a la vez pasa de 4073 lecturas a 528 combinando los bitmaps con BITMAP AND. El bitmap de región ocupa 114 hojas frente a 1954 del B-tree.
Agrupamiento, equilibrio y sargabilidad (E, F)

7: IX_PED_FECHA tiene CF 5220, casi igual que los 5320 bloques de la tabla: los pedidos se cargaron en orden de fecha, así que filas seguidas en el índice están en el mismo bloque. IX_PED_CLIENTE tiene 999 041, casi el número de filas, porque id_cliente se repartió al azar y casi cada entrada salta a otro bloque (04-agrupamiento-equilibrio). Un REBUILD no lo arregla: el CF depende de cómo están ordenadas las filas en la tabla, no del índice. Habría que reordenar la tabla.

8: El índice con CF malo lee 4875 al 0,5 % y 9920 al 1 %, cuando la tabla entera son 5232: deja de compensar entre el 0,5 % y el 1 %, que cuadra con la fórmula en lecturas lógicas (1/bfr = 1/188 = 0,53 %). El optimizador cambia antes, entre el 0,1 % y el 0,2 %, porque supone que la lectura aleatoria es más cara (fórmula con disco: 0,11 %). El índice con CF bueno solo pierde al 100 %: 7875 frente a 5232 (04-agrupamiento-equilibrio).

9: Porque LIKE 'Gonz%' sí es sargable y el índice se puede usar, pero devuelve 2056 filas (el 2,1 % de los clientes) repartidas por toda la tabla, con un CF malo. Cada fila es casi un bloque distinto y suman 2024 lecturas, más que las 1517 de la tabla (05-sargabilidad). Está por encima del punto de equilibrio: que una consulta sea sargable no quiere decir que usar el índice compense.

Coste de escritura y mantenimiento (G, H)

10: Por fila: 10,1 bloques con los 4 índices de hoy, 20,2 con los 9 de la propuesta del compañero y 12,1 con los 5 de V005 (06-indices). La fórmula de 2 bloques de la tabla más 2 por índice se cumple. Rechacé:

IX_PED_CANAL: no se usa (USED = NO) y canal tiene solo 3 valores, el 33 % de la tabla cada uno.
IX_PED_ESTADO: 4 valores, el 25 % cada uno. Solo interesa 'P' y eso lo hace mejor el índice parcial (54 hojas).
IX_PED_FEC_CLI: no se usa y IX_PED_FECHA ya cubre esas consultas.
IX_PED_CLI_FEC: lo sustituye el cubriente, que empieza por id_cliente y además evita ir a la tabla.

De la propuesta solo se queda IX_PED_CP, que sí se usa (Q3) y cada código postal es el 0,009 % de la tabla.

11: - IX_AZAR (50/50): 595 divisiones y ninguna 90/10. Hojas al 75 % de media, histograma repartido entre el 40 y el 99 %, mapa mezclado de = y -.

IX_CRECIENTE (90/10): 398 divisiones, todas 90/10. Hojas al 99,9 %, mapa entero de #.
IX_COLA (patrón cola): mapa vacío a la izquierda y lleno a la derecha, 224 hojas vacías y 70 497 entradas borradas. "Dame el siguiente mensaje" cuesta 226 lecturas frente a 2 en un índice sano.

12: COALESCE: va en línea, no bloquea y es barato. En mi prueba dejó el índice en 201 hojas, quitó todas las entradas borradas y el siguiente mensaje volvió a costar 2 lecturas (07c-remedios). Si además quisiera devolver espacio, SHRINK SPACE (de 4 a 1,69 MB). El REBUILD no hace falta para esto. La solución de verdad sería particionar por fecha y vaciar particiones enteras.

SCN, control files, redo y FRA (I a L)

13: El SCN del último checkpoint que guarda el control file (v$datafile) con el que tiene la cabecera de cada datafile (v$datafile_header). En mi evidencia coinciden: 4050746 en los dos sitios ("sincronizado") y, tras el ALTER SYSTEM CHECKPOINT, 4056169 en los dos (08-scn-checkpoint). Si no coincidieran, ese archivo necesitaría recuperación. PDB$SEED se queda en 2098101 porque está en solo lectura.

14: Protege si se borra o se estropea una de las copias: en el simulacro B borré control03.ctl, copié control01.ctl encima y la base abrió con las tres. No protege si se pierde el disco o el volumen, porque las tres copias están en el mismo sitio y se irían juntas. En producción cada copia va en un disco distinto (o en ASM con redundancia) y se activa CONTROLFILE AUTOBACKUP en RMAN.

15: CURRENT es el grupo en el que escribe LGWR. ACTIVE ya no es el actual, pero sus cambios todavía no están todos en los datafiles y haría falta para recuperar la instancia. INACTIVE ya está en los datafiles y se puede reutilizar. Al principio el grupo 3 estaba CURRENT y el 1 y el 2 INACTIVE. Tras los dos cambios de log, el 2 pasó a CURRENT y el 1 y el 3 a ACTIVE. Oracle rechaza los borrados para protegerse:

4a, ORA-01623: no se puede borrar el grupo CURRENT.
4b, ORA-01609: no se puede borrar un miembro del grupo CURRENT.
4c, ORA-01624: en mi caso el grupo 1 seguía ACTIVE y se necesitaba para una posible recuperación. En el documento sale ORA-01567 (quedarían menos de 2 grupos), pero yo tengo 3 grupos, así que el motivo fue otro.

16: Al bajar la FRA a 2 MB, el alert log avisa con ORA-19815 (FRA al 100 %). ARCn intenta archivar el grupo lleno y no puede: ORA-19809 (límite superado) y ORA-16038 (el log 1, secuencia 28, no se puede archivar). Los grupos se quedan con ARC = NO y LGWR no puede reutilizar uno sin archivar. Cuando necesita cambiar de log, las sesiones se quedan esperando ("log file switch (archiving needed)") y las conexiones nuevas reciben ORA-00257. Al volver a poner 4 GB, ARCn archiva solo y los grupos pasan a ARC = YES.

Undo, WAL y simulacros (M a P)

17: En el paso 1, A ya ha cambiado la fila 101 a EGRESADO sin confirmar y B la lee sin esperar: ve ACTIVO, el valor confirmado, que Oracle reconstruye con el undo de A (1 bloque y 1 registro de undo, paso 2). En el paso 3 se ve que A tiene un bloqueo TM modo 3 en la tabla y TX modo 6 en la fila. En el paso 4, B intenta bloquear la fila con FOR UPDATE y falla con ORA-00054 a los 3 segundos. Leer no espera a nadie; solo se bloquean dos que quieren escribir la misma fila.

18: Para deshacer un INSERT basta con apuntar "borra esta fila", pero para deshacer un DELETE hay que guardar la fila entera y sus entradas de índice. Por eso el INSERT de 10 000 filas dejó 141 bloques de undo y el DELETE 427 (12-undo-y-redo). El ROLLBACK genera redo porque deshacer es aplicar cambios a los bloques, y esos cambios también se protegen con redo: el ROLLBACK del DELETE generó 4701 KB.

19: Justo después del COMMIT está en el redo log online: LGWR escribió 8519 KB en 11 escrituras, mientras DBWn había escrito 0 bloques y la tabla tenía 231 bloques sucios en memoria. Si la base cae en ese momento, el redo permite rehacer el cambio. Después del checkpoint, DBWn escribió 625 bloques y quedaron 0 sucios: ahora el cambio también está en los datafiles.

20: Antes del SHUTDOWN ABORT confirmé la 102 (EGRESADO) y dejé sin confirmar la 103 (INACTIVO). Al arrancar, el alert log muestra "Beginning crash recovery", "Recovery starting at checkpoint rba (logseq 30 block 68025)" y "read 19 KB redo, 14 data blocks need recovery". Ese es el roll forward: SMON aplica el redo desde el último checkpoint. Después, con el undo, deshace lo no confirmado (roll back). Resultado: la 102 sigue EGRESADO y la 103 vuelve a ACTIVO (14a-caida-instancia). Bastó con un STARTUP normal.

21: C (tabla borrada con PURGE, restaurando la copia completa): RTO de 66 s, y el RPO es todo lo hecho desde la copia (aquí solo 1 s porque la copia se hizo justo antes). D (datafile perdido, con RMAN): RTO de 11 s (12 s desde el fallo) y RPO 0, porque la fila 104 cambiada después de la copia apareció como EGRESADO. Son tan distintos porque en C se restaura la base entera (1,7 GB) y se vuelve al momento de la copia, mientras que en D solo se restaura un archivo y RECOVER aplica el redo archivado hasta ahora.

22: En el bloque 5 de mi runbook (15-healthcheck) salen estos errores, y los clasifico así:
- ORA-63999, ORA-01110 (data file 16, academia01.dbf) y ORA-01113 (file 21 needs media recovery): efecto del laboratorio, simulacro D (Parte O). Borré academia01.dbf, Oracle cerró FREEPDB1 y al reabrirla revisó las cabeceras de sus datafiles. La PDB terminó en READ WRITE y la verificación final da OK, así que no queda nada pendiente.
- ORA-00202 (control03.ctl) y ORA-205 durante el MOUNT: efecto del laboratorio, simulacro B (borré control03.ctl a propósito).
- ORA-00800 (Set Priority Failed en LGWR y VKTM): ruido conocido del entorno, ya clasificado en el Lab 4. El contenedor no deja a Oracle subir la prioridad de esos procesos, pero la base funciona normal.

El runbook solo enseña los 10 últimos, por eso no aparecen los de la FRA llena de la Parte L. Ninguno es un incidente real.
2. Tipo examen

S1: B. Con CF cercano a las filas, cada fila del rango es un bloque distinto. (Parte E)

S2: A, C. Índice sobre UPPER(email), o aplicar LOWER al dato que llega. (Parte D, F)

S3: B. Oracle aplica TO_NUMBER a la columna y ya no puede usar el índice. (Parte F)

S4: B. Pocos valores y cargas de noche: lo ideal para bitmap. (Parte D)

S5: B. Sin la primera columna, Oracle hace un SKIP SCAN (una búsqueda por país). (Parte D)

S6: B. Invisible: el optimizador lo ignora pero se sigue manteniendo y se vuelve atrás al momento. (Parte G)

S7: A, C. COALESCE y SHRINK SPACE van en línea y arreglan la cola. (Parte H)

S8: B. Reparte las inserciones, pero el rango hizo recorrido completo (866 lecturas). (Parte H)

S9: C. Si la columna no está en ningún índice, solo cambia la tabla (2 bloques). (Parte G)

S10: B. La altura depende de cuántas entradas caben en cada rama. (Parte C)

S11: A, C. La tabla es el índice: se ahorra el salto a la tabla. (Parte D)

S12: B. Compara el SCN de checkpoint del control file con el de la cabecera. (Parte I)

S13: C. CKPT apunta el checkpoint; DBWn es el que escribe los bloques. (Parte I)

S14: B, E. En NOMOUNT solo hay instancia: v$instance y v$parameter funcionan, lo demás necesita el control file. (Parte O, simulacro B)

S15: B. El modo de archivado se cambia con la base montada, no abierta. (Parte L)

S16: B. Si está INACTIVE y archivado, CLEAR LOGFILE lo recrea sin perder nada. (Parte K)

S17: A, C. Lectura consistente y flashback query. (Parte M)

S18: B. El undo vive en bloques que se pueden perder; hay que poder rehacerlos antes de deshacer. (Parte M)

S19: A. El COMMIT solo espera a que el redo esté en el redo log online. (Parte N)

S20: A. Más checkpoints incrementales, menos redo pendiente y recuperación más rápida. (Parte I)

S21: B. ARCn no puede archivar porque la FRA está llena. (Parte L)

S22: B. Primero se aísla el archivo con OFFLINE para que el resto siga en servicio. (Parte O, simulacro D)

S23: B. Con SYSTEM no se puede seguir abierto: montar, restaurar, recuperar y abrir. (Parte O)

S24: B. Sin redo archivado solo queda volver a la última copia en frío. (Parte L, O)

S25: B, D. Más retención y espacio de undo; RETENTION GUARANTEE si es crítico. (Parte M)

S26: A. V$RECOVERY_AREA_USAGE da el uso por tipo de archivo. (Parte L)

3. Simulacros: RTO y RPO

A, caída de la instancia (SHUTDOWN ABORT): se recupera solo con un STARTUP normal. RTO: lo que tarda el arranque. RPO: 0.
B, se borra control03.ctl: copiar control01.ctl encima, MOUNT y OPEN. RTO: unos segundos. RPO: 0.
C, DROP TABLE ... PURGE: restaurar la copia completa. RTO: 66 s. RPO: todo lo hecho desde la copia (aquí 1 s).
D, se borra academia01.dbf: RMAN, RESTORE + RECOVER del archivo. RTO: 11 s (12 s desde el fallo). RPO: 0.

En el simulacro D me tocó el camino de PDB cerrada: al poner el archivo OFFLINE salió ORA-01089 porque Oracle estaba cerrando FREEPDB1. El script esperó a que quedara MOUNTED, lo restauró y volvió a abrir la PDB.

Retrospectiva del game day
Lo que me sorprendió: por una sola tabla tuve que restaurar 1,7 GB y volver al momento de la copia, mientras que con RMAN y ARCHIVELOG arreglé un archivo en 11 s sin perder nada. También que Oracle cerrara la PDB por su cuenta.
Qué cambiaría: para un borrado de tabla usaría RMAN RECOVER TABLE en lugar de restaurar la base entera, y antes de reparar un datafile miraría siempre el estado de la PDB en v$pdbs.

Retrospectiva: FRA llena
Impacto: las sesiones se quedan esperando "log file switch (archiving needed)". No se pierden datos.
Causa: repetir cargas grandes con ARCHIVELOG activo; en el lab lo provoqué bajando la FRA a 2 MB.
Solución: devolver la FRA a 4 GB (ARCn archiva solo) o liberar espacio con RMAN, nunca con rm.
Qué cambia: el runbook avisa al 80 % de la FRA. El aviso (ORA-19815) llega antes que el bloqueo; hay que mirarlo.
