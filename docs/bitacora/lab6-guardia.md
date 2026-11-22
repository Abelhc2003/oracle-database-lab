Nota: abrí los tres incidentes seguidos, así que coincidieron en el tiempo. Los resolví en orden: 601, 602 y 603.

## INC-601 · La pantalla de secretaría se queda colgada
- Detección: 18:55 UTC. Avisó Ana García (secretaría) con un ticket: al guardar la ficha del alumno 101 la pantalla se quedaba colgada.
- Impacto: Ana no pudo guardar la ficha del alumno 101 desde las 18:55 hasta las 19:04 (unos 9 minutos, según ASH).
- Diagnóstico: con 08-diagnostico.sql vi que la sesión de Ana (SID 204) esperaba en "enq: TX - row lock contention" y que la bloqueaba la SID 220 (APP_ACADEMIA, módulo matriculas, acción cierre-periodo). La 220 tenía el TX en modo 6 y una transacción sin confirmar de 1 registro desde las 18:55:19, y estaba en "PL/SQL lock timer", o sea, parada sin hacer nada.
- Causa raíz: la aplicación de matrículas modificó la fila del alumno 101 en el cierre de periodo y dejó la transacción abierta, sin commit ni rollback, así que la fila se quedó bloqueada para los demás.
- Intervención: ALTER SYSTEM KILL SESSION '220,2132' IMMEDIATE; Era lo más pequeño: solo se termina la sesión que bloquea (no la de Ana ni la instancia) y solo había 1 registro que deshacer.
- Validación: la fila 101 quedó en ACTIVO y en el diagnóstico final ya no había nadie esperando ni bloqueos (secciones 1 a 4 vacías).
- Acción preventiva: que el equipo de matrículas revise que el cierre de periodo haga commit o rollback al terminar, y vigilar las sesiones bloqueadas con la lista de turno (pregunta 6) para enterarnos antes de que llame un usuario.

## INC-602 · La aplicación no conecta: ORA-12514
- Detección: 18:56 UTC. Avisó el equipo de matrículas: ninguna instancia de la aplicación conectaba y salía ORA-12514.
- Impacto: la aplicación de matrículas no pudo conectar desde las 18:56 hasta que arranqué el servicio, sobre las 19:05.
- Diagnóstico: la base y FREEPDB1 estaban abiertas, así que no estaba caída. En la sección 6 del diagnóstico academia_app salía en NO: el servicio existía pero no estaba arrancado, por eso el listener no lo anunciaba.
- Causa raíz: el servicio academia_app estaba parado y nada vigilaba que estuviera arrancado. ORA-12514 lo da el listener cuando no conoce el servicio, no porque la base esté caída.
- Intervención: EXEC DBMS_SERVICE.START_SERVICE('academia_app') y ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE; Solo se arranca el servicio que faltaba, sin reiniciar la base ni la PDB.
- Validación: lsnrctl status vuelve a mostrar academia_app, en el diagnóstico sale SI y app.sh conecta por academia_app.
- Acción preventiva: dejar guardado el estado con el servicio arrancado (SAVE STATE) para que vuelva solo tras un reinicio, y añadir a la lista de turno una comprobación de que academia_app está en V$ACTIVE_SERVICES.

## INC-603 · La aplicación no entra: ORA-28000
- Detección: 18:56 UTC. Avisó el equipo de matrículas: después del despliegue la aplicación no entraba (ORA-28000) y no habían cambiado la contraseña. El turno de tarde dejó nota de que se había ejecutado el script trimestral de bajas.
- Impacto: la aplicación no pudo iniciar sesión desde las 18:56 hasta que desbloqueé la cuenta, sobre las 19:05.
- Diagnóstico: en la sección 7, APP_ACADEMIA salía LOCKED (no LOCKED(TIMED)) desde las 18:56, con el perfil DEFAULT de 10 intentos. LOCKED sin TIMED quiere decir que la bloquearon a mano, no que fallaran contraseñas.
- Causa raíz: el script de bajas no distingue entre cuentas de personas y cuentas de aplicación, y bloqueó APP_ACADEMIA como si fuera un usuario dado de baja.
- Intervención: ALTER USER app_academia ACCOUNT UNLOCK; Solo se desbloquea esa cuenta, sin cambiar la contraseña ni los permisos.
- Validación: app.sh entró por academia_app con ROL_APP_ACADEMIA y en el diagnóstico final la sección 7 sale vacía.
- Acción preventiva: cambiar el script de bajas para que no toque las cuentas de aplicación (por ejemplo, que solo afecte a cuentas con el perfil PRF_PERSONAS) y revisar la lista de cuentas antes de ejecutarlo.
