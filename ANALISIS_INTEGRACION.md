# Análisis de integración — Nexus Full Stack

## Alcance y método

Auditoría estática de los repositorios clonados `Nexus_React` y `Proyecto_Springboot_Microservicios/proyecto`. Se inspeccionaron rutas y pantallas React, llamadas de red, controladores, DTO, servicios, repositorios, entidades, archivos Maven, configuración Spring, seguridad y Compose.

Esta primera etapa no modifica código de aplicación, no ejecuta pruebas ni inicia contenedores. Las conclusiones describen el código revisado; las propuestas de integración se identifican como plan, no como funcionalidad ya disponible.

## Diagnóstico ejecutivo

- El frontend es una SPA React + Vite con rutas y flujos completos de demostración. No contiene cliente HTTP ni llama a los microservicios; login, registro, catálogo, carrito, compra, administración, contacto, comunidad y streaming son locales o simulados.
- El backend es un proyecto Maven agregador con Eureka, un API Gateway y diez microservicios de negocio. Hay endpoints REST persistentes para autenticación, usuarios, productos, pedidos, pagos, envíos, inventario, notificaciones, reseñas y cupones.
- Los dos repositorios no están integrados a nivel de aplicación. La raíz tiene un Compose que incluye el Compose del backend, pero no define un servicio para el frontend.
- Hay una incompatibilidad importante en la configuración existente: Compose activa el perfil `prod` en varios contenedores, pero los archivos revisados proporcionan configuración `dev` y no se encontraron perfiles `prod` equivalentes. Los puertos, Eureka y propiedades de persistencia esperados en Docker pueden no estar configurados.
- El Gateway valida JWT en rutas protegidas, pero auth y usuarios permiten todas las solicitudes al nivel de servicio; los puertos de los microservicios se publican directamente. No se encontró autorización por rol ni configuración explícita de CORS.
- La configuración existente incluye credenciales de desarrollo directamente en Compose/configuración. Antes de publicar cambios de integración, deben externalizarse y no deben añadirse secretos reales al repositorio.
- El resultado estático no acredita que el stack compile o arranque. Maven, Docker, endpoints y persistencia requieren validación en la fase de implementación.

## 1. Estructura y tecnologías

### Frontend

- `Nexus_React/` contiene una aplicación JavaScript/JSX organizada en `src/pages`, `src/components`, `src/data`, `src/utils` y `src/styles`; las pruebas están junto al código y hay pruebas de aplicación/compra en la raíz de `src`.
- React y React DOM `^19.2.8`, React Router `^8.4.0`, Bootstrap `^5.3.8`, Vite `^8.3.0`, Vitest `5.0.5`; versiones resueltas se encuentran en `package-lock.json`. No hay versión de Node fijada en el manifiesto.
- Scripts disponibles: `dev`, `build`, `lint`, `test`, `test:run` y `test:coverage`. Vitest está configurado con jsdom en `vite.config.js`.
- No se encontró `fetch`, Axios, `XMLHttpRequest`, API client, URL de servicio local ni ruta `/api/` en el código de `src`.

### Backend

El agregador `Proyecto_Springboot_Microservicios/proyecto/pom.xml` incluye 12 módulos. Los módulos declaran Java 21, Spring Boot 4.0.6 y Spring Cloud 2025.1.1 en sus POM; los microservicios de negocio usan Springdoc 3.0.3.

| Módulo | Puerto configurado en Compose/dev | Rol y dependencias principales |
|---|---:|---|
| `eureka-server` | 8761 | Registro Eureka y Actuator. |
| `api-gateway` | 8080 | Spring Cloud Gateway MVC, Eureka client, Actuator, Springdoc y validación JWT. |
| `ms-auth` | 8083 | MVC, JPA, validación, Eureka, MySQL, Flyway, Spring Security y JWT. |
| `ms-usuarios` | 8081 | MVC, JPA, validación, Eureka, MySQL y Spring Security. |
| `ms-productos` | 8082 | MVC, JPA, validación, Eureka, MySQL; cliente de inventario. |
| `ms-pedidos` | 8084 | MVC, JPA, validación, Eureka, MySQL; cliente de productos. |
| `ms-pagos` | 8085 | MVC, JPA, validación, Eureka y MySQL. |
| `ms-envios` | 8086 | MVC, JPA, validación, Eureka y MySQL. |
| `ms-inventario` | 8087 | MVC, JPA, validación, Eureka y MySQL. |
| `ms-notificaciones` | 8088 | MVC, JPA, validación, Eureka y MySQL. |
| `ms-resenas` | 8089 | MVC, JPA, validación, Eureka y MySQL. |
| `ms-cupones` | 8090 | MVC, JPA, validación, Eureka y MySQL. |

La tabla refleja los puertos de Compose/configuración dev revisados, no garantiza que los contenedores actuales escuchen en ellos con el perfil que Compose activa.

## 2. Contratos REST existentes

Las rutas siguientes son las declaradas por los controladores. Los tipos de request/response son los DTO referenciados por esos métodos; el frontend debe mapear los campos contra sus declaraciones antes de enviar datos.

| Servicio | Métodos y rutas | DTO / resultado |
|---|---|---|
| Auth | `POST /api/v1/auth/login`; `POST /api/v1/auth/register` | `LoginRequest` → `AuthResponse`; `RegisterRequest` → `AuthResponse`. |
| Usuarios | `GET /api/v1/usuarios`; `GET /api/v1/usuarios/{id}`; `POST /api/v1/usuarios`; `PUT /api/v1/usuarios/{id}`; `DELETE /api/v1/usuarios/{id}` | `UsuarioDTO`; `UsuarioRequestDTO`; DELETE sin cuerpo, 204 según controlador. |
| Productos | `GET /api/v1/productos`; `GET /api/v1/productos/{id}`; `GET /api/v1/productos/categoria/{cat}`; `POST /api/v1/productos`; `PUT /api/v1/productos/{id}`; `PUT /api/v1/productos/{id}/stock/decrement?cantidad=...`; `DELETE /api/v1/productos/{id}` | `ProductoDTO`; `ProductoRequestDTO`; decremento sin cuerpo; DELETE 204 según controlador. |
| Pedidos | `GET /api/v1/pedidos`; `GET /api/v1/pedidos/{id}`; `GET /api/v1/pedidos/usuario/{uid}`; `POST /api/v1/pedidos`; `PATCH /api/v1/pedidos/{id}/estado?estado=...` | `PedidoDTO`; `PedidoRequestDTO`. |
| Pagos | `GET /api/v1/pagos`; `GET /api/v1/pagos/{id}`; `GET /api/v1/pagos/pedido/{pedidoId}`; `POST /api/v1/pagos`; `PATCH /api/v1/pagos/{id}/reembolsar` | `PagoDTO`; `PagoRequestDTO`. |
| Envíos | `GET /api/v1/envios`; `GET /api/v1/envios/{id}`; `GET /api/v1/envios/seguimiento/{codigo}`; `POST /api/v1/envios`; `PATCH /api/v1/envios/{id}/estado?estado=...` | `EnvioDTO`; `EnvioRequestDTO`. |
| Inventario | `GET /api/v1/inventario`; `GET /api/v1/inventario/bajo-stock`; `GET /api/v1/inventario/producto/{productoId}`; `POST /api/v1/inventario`; `PATCH /api/v1/inventario/producto/{productoId}/ajustar?cantidad=...` | `InventarioDTO`; `InventarioRequestDTO`. |
| Notificaciones | `GET /api/v1/notificaciones/usuario/{uid}`; `GET /api/v1/notificaciones/usuario/{uid}/no-leidas`; `POST /api/v1/notificaciones`; `PATCH /api/v1/notificaciones/{id}/leer` | `NotificacionDTO`; `NotificacionRequestDTO`. |
| Reseñas | `GET /api/v1/resenas/producto/{pid}`; `GET /api/v1/resenas/usuario/{uid}`; `GET /api/v1/resenas/producto/{pid}/promedio`; `POST /api/v1/resenas`; `DELETE /api/v1/resenas/{id}` | `ResenaDTO`; `ResenaRequestDTO`; promedio como `Map<String,Object>`; DELETE 204 según controlador. |
| Cupones | `GET /api/v1/cupones`; `POST /api/v1/cupones`; `GET /api/v1/cupones/{codigo}/validar?monto=...`; `POST /api/v1/cupones/{codigo}/aplicar` | `CuponDTO`; `CuponRequestDTO`; validar devuelve `Map<String,Object>`; aplicar sin cuerpo. |

Los controladores delegan en servicios, y estos usan repositorios Spring Data JPA y entidades. El flujo entre microservicios identificado en código incluye Auth → Usuarios (sincronización de perfil), Productos → Inventario y Pedidos → Productos (consulta/decremento de stock). No se debe inferir que esas llamadas componen una transacción distribuida.

## 3. Persistencia y configuración backend

- Compose ejecuta MySQL 8.4, publica host `3307` → contenedor `3306`, conserva datos en el volumen nombrado `mysql_data` y ejecuta `docker/mysql/init.sql`.
- El SQL inicial crea bases lógicas para auth/usuarios y cada dominio de negocio; no crea las tablas de negocio. Auth tiene migración Flyway para `auth_users`; los perfiles dev de otros servicios declaran `ddl-auto=update`.
- Auth usa la base `db_usuario`; usuarios usa `db_usuarios`. Las otras bases son `db_productos`, `db_pedidos`, `db_pagos`, `db_envios`, `db_inventario`, `db_notificaciones`, `db_resenas` y `db_cupones`.
- Eureka está en 8761; el Gateway está en 8080 y sus rutas usan el registro de servicios. El Gateway permite login/registro y rutas de documentación/actuator antes de exigir JWT; en rutas protegidas valida el token y agrega encabezados de identidad.
- Los `SecurityConfig` revisados de Auth y Usuarios permiten cualquier solicitud; no se encontró una configuración equivalente en los demás servicios. Al publicar puertos de servicio en el host, se puede acceder a ellos sin pasar por el filtro JWT del Gateway.
- No se encontró configuración explícita de CORS en los servicios o el Gateway.

### Inconsistencias observadas que bloquean o confunden la ejecución

1. El Compose backend activa perfiles `prod` para Eureka y servicios, pero los recursos revisados tienen configuración `application-dev.properties` y no muestran perfiles `application-prod.properties`. Dev contiene puertos, nombres de aplicación/servicio, Eureka y configuración JPA relevantes; no debe asumirse que estén disponibles al activar `prod`.
2. Los puertos de servicios en Compose/dev no coinciden con parte de la tabla del README. El README asigna Auth a 8089 y desplaza algunos puertos de Pedidos/Pagos/Envíos/Inventario/Notificaciones/Reseñas.
3. La documentación menciona host MySQL 3306, base `db_auth` y usuario técnico `foodexpress`; Compose configura host 3307, `db_usuario` para Auth y no define ese usuario técnico.
4. El README y las propiedades de documentación del Gateway muestran rutas OpenAPI con `/api/v1/...`, mientras las rutas de docs dev descritas en `application-dev.properties` usan rutas de servicio distintas. Deben verificarse al ejecutar; no son necesarias para la integración funcional inicial.
5. El Compose existente contiene valores de credenciales de desarrollo y secretos JWT versionados. La integración debe externalizarlos; `.env.example` contendrá solo valores ficticios/de ejemplo y `.env` real se excluirá de Git.

## 4. Pantallas y comportamiento frontend existente

Las rutas están declaradas en `Nexus_React/src/App.jsx`; todas las rutas protegidas actualmente se controlan en el cliente.

| Ruta/pantalla | Comportamiento actual | Correspondencia backend |
|---|---|---|
| `/`, `/login` | Login/registro local y opción de invitado. | Auth tiene login y registro; falta conectar, mapear DTO y conservar token/sesión sin guardar contraseñas. |
| `/principal` | Portada, búsqueda/canales y contenido de ejemplo. | Productos permite consultar catálogo; no hay servicio evidenciado para transmisiones/canales. |
| `/comunidad` | Chat local, canales y mensajes de demostración. | No hay API de chat/comunidad evidenciada. |
| `/contacto` | Validación local; confirma que el mensaje no se envió. | No hay endpoint de contacto evidenciado. |
| `/perfil` | Edición de perfil local. | Usuarios tiene GET/PUT por id; falta definir relación segura entre usuario autenticado y `uid`. |
| `/tienda`, `/producto` | Catálogo, filtros, selección y carrito local. | Productos tiene consulta/CRUD; inventario expone stock. No hay CRUD de categorías identificado. |
| `/checkout`, `/compra/:id` | Compra, resultado, pedido y descuento de stock simulados en el navegador. | Pedidos crea y consulta por usuario; Pagos crea/reembolsa. El frontend debe respetar contratos y orden de operaciones backend. |
| `/stream` | Reproducción/chat/seguimiento simulados. | No hay API de video/stream/chat evidenciada; reseñas y notificaciones no sustituyen esas funciones. |
| `/admin/login`, `/admin/*` | Credenciales y autorización de demostración; administración local de productos/categorías/clientes/órdenes/reportes. | Productos, Usuarios, Pedidos e Inventario ofrecen operaciones relacionadas, pero no hay categorías CRUD ni autorización de administrador por rol en backend. No se debe presentar la protección cliente actual como seguridad real. |

Los datos de sesión de demostración se guardan en `sessionStorage`; administración local en `localStorage`. El análisis no encontró almacenamiento de contraseñas en esos almacenes. Antes de habilitar endpoints, los flujos locales deben mantenerse para funciones sin soporte y diferenciarse claramente de operaciones persistidas.

## 5. Matriz de integración propuesta

| Funcionalidad | Microservicio y endpoints existentes | Trabajo faltante / límite |
|---|---|---|
| Inicio de sesión y registro | `ms-auth`: POST login/register | Cliente API, validación de respuestas y errores, token en memoria/sesión según contrato `AuthResponse`; nunca persistir contraseña. Verificar expiración y claims JWT. |
| Perfil de usuario | `ms-usuarios`: GET por id y PUT por id; `ms-auth` sincroniza perfil al registrarse | Definir cómo obtener el id asociado a identidad autenticada; no confiar en un id libre enviado por el navegador. |
| Catálogo y detalle | `ms-productos`: GET colección, detalle y categoría | Sustituir solo fuente de productos; conservar filtros de UI que no existan en API. Revisar DTO/campos de imagen y categoría. |
| Administración de productos | `ms-productos`: POST, PUT, DELETE | Requiere autorización backend de rol admin antes de exponer CRUD. |
| Categorías | Ningún endpoint de categorías encontrado | Mantener administración local con aviso de no persistencia o desarrollar API/backend explícitamente en una etapa posterior. |
| Carrito y checkout | `ms-pedidos`: POST; consulta de pedidos por usuario; integración a Productos para validar/decrementar stock. `ms-pagos`: POST y reembolso | Cliente del checkout y manejo de fallos/parcialidad. Acordar contrato de carrito/ítems y flujo de pago con DTO real. No simular aprobación en el cliente cuando se envía pago real. |
| Historial/estado de órdenes | `ms-pedidos`: GET por usuario/id; PATCH estado | Asociar usuario desde JWT; no ofrecer cambios de estado administrativos sin rol backend. |
| Stock | `ms-inventario`: consulta, bajo stock y ajuste; `ms-productos`: decremento | Evitar doble decremento entre pedido/producto/inventario; confirmar idempotencia y límites en implementación. |
| Seguimiento de envío | `ms-envios`: consulta por código, alta y PATCH estado | Integrar el seguimiento existente; no hay API de transporte externo demostrada. |
| Notificaciones | `ms-notificaciones`: listar, no leídas, crear, marcar leída | Integrar vista/notificaciones si existe en UI; no se identificó un componente dedicado ni entrega push. |
| Reseñas | `ms-resenas`: listar, promedio, crear, borrar | No se encontró pantalla dedicada en las rutas inventariadas; el CRUD de reseñas puede quedar como capacidad backend no conectada. |
| Cupones | `ms-cupones`: listar, validar y aplicar | Integrar validación en checkout solo después de comprobar el contrato y comportamiento de aplicar. |
| Contacto, streaming, comunidad/chat | Ningún endpoint correspondiente encontrado | Conservar demos/locales con indicación honesta de alcance; no sustituirlos por servicios de dominio distintos. |

## 6. Plan por etapas para implementar después de esta auditoría

1. **Desbloquear ejecución segura:** corregir la configuración Compose para usar perfiles y puertos coherentes; externalizar credenciales; verificar esquema y usuario de MySQL; agregar healthchecks/esperas para dependencias. Evitar exponer servicios de negocio al host si el Gateway es el acceso público necesario.
2. **Conectar configuración de servicios:** confirmar nombres/rutas Gateway ↔ Eureka y direcciones internas; agregar CORS explícito solo si el navegador contacta directamente al Gateway. Preferir un proxy del frontend hacia el Gateway para evitar CORS y usar nombres de servicio Docker entre contenedores.
3. **Implementar capa API frontend:** cliente HTTP centralizado configurable por entorno, manejo común de JSON/errores/401, estados de carga y mensajes visibles. Consumir el Gateway, no los puertos internos de cada microservicio.
4. **Integrar flujos respaldados, gradualmente:** auth; catálogo/detalle; perfil; luego checkout/pedidos/pagos/stock. Mantener el carrito local como borrador hasta confirmar el pedido y no afirmar persistencia hasta recibir éxito backend. Integrar envíos, notificaciones y cupones donde la UI existente lo permita.
5. **Seguridad:** validar JWT en el Gateway; no almacenar contraseñas; revisar token/expiración/logout; agregar autorización de roles del lado backend para CRUD administrativo. No usar la autorización React como control de acceso.
6. **Funciones sin API:** conservar contacto, chat/streaming, categorías admin y cualquier UI no respaldada, señalando que son locales/no persistentes. Para convertirlas en reales se necesita especificar y desarrollar contratos backend, sin inventarlos en el frontend.
7. **Docker frontend y raíz:** añadir construcción multi-stage del frontend y servicio en Compose raíz; usar `.env.example`, excluir `.env`, mantener el volumen MySQL al hacer `docker compose down` y documentar inicialización/logs.
8. **Validación y documentación:** ejecutar build/lint/pruebas frontend, pruebas Maven agregadas, `docker compose config`, levantar stack, comprobar endpoints mediante Gateway, auth, escritura/lectura MySQL y persistencia después de reiniciar contenedores. Documentar resultados observados en `README_LOCAL.md`; no declarar pruebas no ejecutadas como exitosas.

## 7. Referencias de código revisadas

Rutas relativas a la raíz del workspace:

- Frontend: `Nexus_React/package.json`, `Nexus_React/package-lock.json`, `Nexus_React/vite.config.js`, `Nexus_React/src/App.jsx`, `Nexus_React/src/pages/`, `Nexus_React/src/components/`, `Nexus_React/src/data/`, `Nexus_React/src/utils/`.
- Agregador y módulos backend: `Proyecto_Springboot_Microservicios/proyecto/pom.xml`, `Proyecto_Springboot_Microservicios/proyecto/*/pom.xml`.
- Controladores: `Proyecto_Springboot_Microservicios/proyecto/ms-*/src/main/java/**/controller/`.
- Persistencia: `Proyecto_Springboot_Microservicios/proyecto/ms-*/src/main/java/**/{service,repository,model,entity}/`; inicialización MySQL en `Proyecto_Springboot_Microservicios/proyecto/docker/mysql/init.sql`.
- Configuración: `Proyecto_Springboot_Microservicios/proyecto/docker-compose.yml`, `Proyecto_Springboot_Microservicios/proyecto/api-gateway/src/main/resources/`, `Proyecto_Springboot_Microservicios/proyecto/eureka-server/src/main/resources/` y recursos `src/main/resources/` de los servicios.

**Estado tras la auditoría:** documentado el diagnóstico y la propuesta de integración. Aún no se ha implementado ni validado la integración en ejecución.
