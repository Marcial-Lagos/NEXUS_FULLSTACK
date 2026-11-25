# NEXUS Fullstack

Tienda universitaria de productos gaming. React sirve el catálogo, el carrito, el perfil y la administración. Spring Boot valida las cuentas, procesa los pedidos y registra los pagos simulados en MySQL 8.4. El carrito sobrevive a una recarga de la pestaña. Los pedidos quedan asociados a la cuenta y se pueden consultar al volver a iniciar sesión.

## Descargar el proyecto

La entrega usa dos submódulos de Git. Desde una copia existente, ejecuta `git submodule update --init --recursive`. Para clonar la versión integrada desde cero:

```sh
git clone --recurse-submodules --branch entrega/tienda-integrada https://github.com/Marcial-Lagos/NEXUS_FULLSTACK.git
cd NEXUS_FULLSTACK
```

## Ejecutar en Windows

Requiere JDK 25, Maven 3.9 y Node.js 24. En PowerShell, desde la carpeta principal:

```powershell
.\Nexus.cmd
```

Abre **http://127.0.0.1:5173** cuando la consola anuncie que Nexus está disponible. La primera ejecución compila los servicios, instala las dependencias del frontend y prepara las bases de datos. Usa MySQL 8.4 en una instancia propia sobre el puerto 33307. Si el ejecutable no está instalado, el iniciador descarga la distribución portátil para Windows x64 y verifica su SHA-256. Para indicar otra instalación, usa `.\Nexus.cmd -MySqlBin 'C:\ruta\mysql\bin'`.

El proyecto conserva datos, registros, identificadores de proceso y credenciales en `.nexus-local`. El acceso administrativo se genera para esa instalación. Consulta los campos `adminEmail` y `adminPassword` en `.nexus-local/config.json` y entra por **/admin/login**. Mantén ese archivo privado.

| Acción | Comando en PowerShell |
| --- | --- |
| Iniciar o consultar los procesos del proyecto | `.\Nexus.cmd` |
| Aplicar cambios de código, recompilar y volver a iniciar | `.\Nexus.cmd -Recompilar` |
| Detener Nexus y conservar MySQL en disco | `.\Nexus.cmd -Detener` |

## Ejecutar con Docker Compose

Con Docker en modo de contenedores Linux y Node.js instalado, ejecuta desde la raíz:

```sh
node scripts/configurar-docker.mjs
docker compose up --build -d
```

La tienda utiliza el mismo puerto 5173. El frontend envía las solicitudes de `/api/` al Gateway por la red de Compose. Eureka utiliza el puerto 8761, el Gateway 8080 y MySQL 3307 en el host. El volumen `mysql_data` conserva las compras al ejecutar `docker compose down`. Detén la ejecución nativa antes de levantar Docker en esos puertos. Las credenciales de esta instalación se generan en `.env`.

## Recorrido de la tienda

1. Entra como invitado para explorar el catálogo o regístrate con un correo. Desde **Tienda**, abre la ficha de un producto y agrégalo al carrito.
2. Confirma el pedido con tu cuenta. Puedes retirarlo en tienda o solicitar despacho por $3.990 CLP. El servidor calcula precios y ofertas, comprueba las existencias y registra el comprobante del pago de prueba.
3. Abre **Perfil → Mis pedidos** para ver el detalle, el monto y el estado. Reenviar el mismo intento de compra conserva un solo pedido, descuento de stock y pago.
4. En **/admin/login**, el administrador puede crear, editar o retirar productos, asignar precios de oferta y categorías, revisar cuentas e inventario y actualizar el estado de los pedidos.

Los pagos son simulados. El chat de comunidad, el streaming y el formulario de contacto son funciones de demostración. La documentación de las diez API de negocio está en **http://127.0.0.1:8080/doc/swagger-ui.html**.

## Comprobación

```sh
# Con Nexus en marcha, desde la raíz
node scripts/probar-tienda.mjs

# Desde Nexus_React
npm run lint
npm run test:run
npm run build

# Desde Proyecto_Springboot_Microservicios/proyecto, con JDK 25
mvn test
```

Para probar la instalación de Docker, ejecuta `node --env-file=.env scripts/probar-tienda.mjs` desde la raíz.

La prueba de la tienda crea una cuenta, un producto y un pedido de prueba. Retira el producto al finalizar y conserva los comprobantes. Lee el acceso administrativo de la configuración nativa o de las variables `NEXUS_ADMIN_EMAIL` y `NEXUS_ADMIN_PASSWORD`. Puedes definir `NEXUS_URL` para otra instancia de pruebas.

[Frontend React](./Nexus_React) · [Microservicios Spring Boot](./Proyecto_Springboot_Microservicios) · [Análisis inicial del proyecto](./ANALISIS_INTEGRACION.md)

## Persistencia de chats

El API Gateway usa JDBC con las variables SPRING_DATASOURCE_* y el esquema existente db_usuario. Al arrancar ejecuta schema.sql con CREATE TABLE IF NOT EXISTS para las tablas nexus_chat_directo y nexus_chat_mensaje. No modifica tablas comerciales existentes. En LGND el arranque local configura el Gateway con jdbc:mysql://127.0.0.1:33307/db_usuario; Docker Compose ya define el datasource. El historial de directos publicos y comunidades requiere JWT. Los chats guardan el ID de usuario autenticado, texto, canal y fecha; no guardan audio/video. Para produccion, separar permisos y esquema del chat, establecer moderacion, politica de retencion y backups, y probar TURN.

Pruebas opcionales con MySQL real: desde api-gateway ejecutar mvn test con NEXUS_TEST_MYSQL_URL (URL base jdbc:mysql://host:puerto/), NEXUS_TEST_MYSQL_USER y NEXUS_TEST_MYSQL_PASSWORD definidos localmente. HistorialMySqlTest crea y elimina un esquema temporal de nombre aleatorio exclusivamente para las pruebas. No guardar credenciales en Git.
