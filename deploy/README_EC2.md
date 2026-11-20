# NEXUS_FULLSTACK en EC2

Esta configuración sigue el flujo del ejemplo docente: GitHub Actions construye las imágenes Docker y las transfiere a una EC2 por SSH. La instancia ejecuta las imágenes; no necesita Java, Maven ni Node.js.

## Instancia

Para la demo se recomienda Amazon Linux 2023 x86_64, 4 vCPU, 16 GiB de RAM y 50 GiB gp3. La compilación se hace en GitHub Actions para reducir la carga de EC2.

En el asistente de lanzamiento:

1. Crea o elige un par de claves y conserva el archivo privado `.pem` en un lugar seguro.
2. Permite HTTP (`80/TCP`) desde Internet para abrir la web.
3. Para el flujo SSH de GitHub Actions, habilita SSH (`22/TCP`). Los runners hospedados tienen IP cambiantes; este flujo requiere permitir SSH desde cualquier IPv4 (0.0.0.0/0). Usa una llave SSH sin contraseña y elimina la regla cuando ya no sea necesaria. Para producción, usa acceso sin SSH público, por ejemplo AWS Systems Manager.
4. En **Advanced details → User data**, pega el contenido de `deploy/ec2-user-data.sh`.
5. Deja un volumen raíz gp3 de 50 GiB. No abras los puertos 3306, 8080 ni 8761 a Internet.

El Gateway y Eureka quedan enlazados a `127.0.0.1` en EC2; MySQL queda dentro de la red Docker. El navegador entra por el frontend en el puerto 80 y Nginx envía `/api/*` al Gateway por la red de Compose. Esto evita CORS entre la web y la API.

## Secretos de GitHub Actions

En el repositorio principal `NEXUS_FULLSTACK`, abre **Settings → Secrets and variables → Actions** y agrega:

- `EC2_HOST`: IPv4 pública de la instancia.
- `EC2_USER`: `ec2-user`.
- `EC2_SSH_KEY`: contenido completo del archivo privado `.pem`.

No subas el archivo `.pem`, JWT ni contraseñas al repositorio. El flujo crea un `.env` aleatorio en EC2 en el primer despliegue y lo conserva después.

## Desplegar

El workflow `.github/workflows/deploy-ec2.yml` se ejecuta al subir cambios a `main` o desde **Actions → Deploy NEXUS_FULLSTACK to EC2 → Run workflow**. Espera a que termine el primer arranque de User Data antes de ejecutar el primer despliegue.

La aplicación quedará en `http://<IPv4-pública-de-EC2>/`. El frontend llama al Gateway a través de Nginx. El README de React describe qué flujos están conectados al backend; varias funciones siguen siendo demostraciones locales.

## Seguridad y costos

Es una demo en HTTP, sin dominio ni TLS. Para producción, usa HTTPS, acceso sin SSH público (por ejemplo AWS Systems Manager), un usuario MySQL dedicado, autorización por roles y configuración Spring de producción.

EC2 factura mientras está encendida; también se factura el disco gp3 y la IPv4 pública. Detener la instancia detiene el cómputo, pero deja los cargos de almacenamiento y otros recursos.
