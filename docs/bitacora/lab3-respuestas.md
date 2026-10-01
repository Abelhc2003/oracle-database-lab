# Lab 3 - Respuestas de comprobación

## Docker

**1. ¿Diferencia entre imagen y contenedor?**
La imagen es la plantilla de solo lectura y el contenedor es una instancia en marcha creada a partir de ella. En el G2 usé la imagen hello-world y docker run creó un contenedor con nombre aleatorio. En el G4 usé la imagen alpine:3.20 y creé el contenedor prueba. Con la misma imagen puedes hacer varios contenedores (prueba, prueba2...).

**2. ¿Por qué nota.txt desapareció en el G5 y en el G6 no?**
En el G5 lo escribí en /tmp, dentro del sistema de archivos del contenedor, que es temporal. Al hacer docker rm prueba se borró con él, y prueba2 salió de la imagen limpia. En el G6 lo escribí en un volumen (datos-prueba), que vive fuera del contenedor, así que el contenedor nuevo lo encontró.

**3. ¿docker ps vs docker ps -a y qué es Exited (0)?**
docker ps solo enseña los contenedores en marcha y docker ps -a enseña todos, también los parados. Exited (0) significa que el contenedor ya no corre y terminó bien, sin errores. Si fuera Exited (1) o más, terminó con error.

**4. -p 8181:8181 y -p 80:8080**
El número de la izquierda es el de mi equipo y el de la derecha el del contenedor (anfitrión:contenedor). Con -p 80:8080 en el nginx, mi puerto 80 iría al 8080 del contenedor, pero nginx escucha en el 80, así que la página no cargaría. Había que poner 8080:80.

**5. ¿Por qué Oracle se queda en marcha y hello-world termina solo?**
Un contenedor vive lo que vive su proceso principal. hello-world imprime su mensaje y acaba, así que el contenedor termina. En Oracle el proceso principal es el motor de la base de datos, que no termina, por eso sigue Up.

**6. ¿Qué es el digest y por qué lo registramos si usamos :latest?**
Es la huella digital (sha256) exacta de la imagen: dos personas con el mismo digest tienen exactamente la misma imagen. :latest va cambiando con el tiempo, pero el digest no, así que queda registrado qué versión exacta de Oracle instalé.

**7. ¿Qué borra de verdad los datos de Oracle?**
docker volume rm oralab-26ai-data. docker rm oralab-26ai solo borra el contenedor, pero los datos están en el volumen (/opt/oracle/oradata), que sigue existiendo.

## Git, organización y evidencia

**8. ¿Por qué dentro del repositorio con Issue, branch y PR?**
Porque así no pierdo la conexión con GitHub, el historial ni la protección de main. Además hace el entorno reproducible (si se rompe el portátil repito los scripts), verificable (el reviewer ve scripts y salidas reales) y sirve para que otro compañero lo monte leyendo el repo.

**9. source 00-config.sh vs bash 00-config.sh**
bash ejecuta el script en una terminal hija que desaparece al acabar, y las variables se pierden. source lo ejecuta en mi propia terminal y las variables se quedan. Por eso uso source, y hay que repetirlo si cierro la terminal.

**10. Nombre 20260915T091230Z_02-docker.script.log**
- 20260915T091230Z: fecha y hora en UTC (15/09/2026, 09:12:30; la Z es UTC).
- 02: número del paso que lo produjo (verificar Docker).
- docker: descripción corta en kebab-case.
- script.log: evidencia de terminal (si fuera de una sesión SQL sería spool.log).

**11. ¿Para qué sirve .gitattributes?**
Para fijar los finales de línea de los .sh, .sql y .md a LF. Evita que un script que viene de Windows con CRLF falle en Linux con errores como "$'\r': command not found".

**12. ¿Por qué merge commit y no squash?**
Porque cada commit corresponde a una Parte y tiene valor propio. Con el merge commit se conserva el historial paso a paso y se ve cuándo y cómo se verificó cada herramienta. Con squash se juntaría todo en un solo commit.

## Seguridad

**13. Las cuatro capas de contraseñas**
1. Poner config/.env y backups/ en .gitignore antes de crear el archivo.
2. Una plantilla config/.env.example versionada, sin secretos.
3. Mi config/.env real, solo local, comprobando con git check-ignore -v y git status que Git lo ignora.
4. Cargar la contraseña con set -a; source config/.env; set +a, sin escribirla nunca a mano.

Si me salto la primera, Git vería el .env al crearlo y podría subirlo con un git add. La contraseña quedaría en el historial para siempre.

**14. ¿Por qué no escribir la contraseña en el docker run?**
Porque todo lo que tecleo se guarda en texto plano en el historial de la terminal (~/.bash_history), aunque el script no se suba a Git. Con "$ORACLE_PWD" solo queda el nombre de la variable.

**15. Contraseña en un commit ya publicado**
No basta con borrarla en un commit nuevo, porque sigue en el historial. Hay que darla por comprometida y cambiarla (recrear el contenedor con otra contraseña en config/.env), y avisar al docente para limpiar la branch.

## Oracle y herramientas

**16. ¿Por qué no SPOOL ni @archivo.sql con sqlplus en el contenedor?**
Porque sqlplus corre dentro del contenedor. Un SPOOL escribiría el archivo en el sistema de archivos del contenedor y no en mi repo, y @archivo.sql buscaría el archivo dentro del contenedor, donde no existe (error SP2-0310). En su lugar uso la redirección < para pasarle el .sql desde mi equipo y tee para guardar la salida en el repo.

**17. WHENEVER SQLERROR EXIT SQL.SQLCODE**
Hace que sqlplus se pare en el primer error y devuelva el código de error. Sin esa línea seguiría ejecutando el resto del script aunque algo fallara, y el script de migraciones no se enteraría del fallo (podría aplicar V001 sobre un V000 roto).

**18. ¿Qué es una migración y por qué no se editan V000 y V001?**
Es un script SQL versionado y numerado que lleva la base de datos de un estado al siguiente, y se aplican en orden. Una vez aplicadas no se editan porque ya se ejecutaron; si hay que corregir algo, se crea una migración nueva.

**19. ¿Por qué FREEPDB1 en SQL Developer y no FREE ni un SID?**
FREEPDB1 es el servicio de la base de datos donde trabajamos (la PDB). FREE o un SID me llevarían al contenedor raíz. Por eso se usa "Service name" con FREEPDB1.

**20. SQLcl frente a SQL*Plus**
SQLcl es la herramienta moderna: autocompletado, historial, formato automático, conexiones guardadas, integración con Liquibase y SPOOL directo en mi equipo. SQL*Plus existe en cualquier servidor Oracle desde 1982, así que si a las 3 de la mañana solo tengo una terminal en el servidor, es lo único que hay. Un DBA debe dominar las dos.

## Entorno de trabajo

**21. ¿Por qué pasar de Git Bash a Ubuntu en WSL 2?**
Porque Git Bash es una emulación y da problemas. Por ejemplo, convierte rutas /opt/... a rutas de Windows y rompe argumentos de Docker, y docker run -it fallaba (hacía falta winpty o PowerShell). Tampoco trae free, ss o htop. En Ubuntu todo eso desaparece porque es Linux real, igual que los servidores y los contenedores.

**22. ¿Por qué ~/oracle-database-lab y no /mnt/c/...? ¿Y bash frente a zsh?**
Trabajar en /mnt/c cruza dos sistemas de archivos, así que Git y Docker van mucho más lentos, no se conservan los permisos de Linux (como el de ejecución) y vuelven los problemas de finales de línea. Y bash porque es la shell por defecto de casi todos los servidores, así que un script en bash funciona en cualquier sitio. zsh es más cómoda para uso personal, pero tiene diferencias sutiles.
