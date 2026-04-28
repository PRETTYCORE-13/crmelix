# Prettycore

Plataforma de e-commerce y gestión de inventario construida con **Elixir + Phoenix LiveView**. Combina integración con el ERP Frog (modo API) y gestión 100 % nativa (modo nativo) en un solo sistema reactivo en tiempo real.

---

## Tabla de Contenidos

1. [Stack Técnico](#stack-técnico)
2. [Arquitectura General](#arquitectura-general)
3. [Perfiles de Usuario (Roles)](#perfiles-de-usuario-roles)
4. [Autenticación y Sesiones](#autenticación-y-sesiones)
5. [Módulos de Negocio (Contexts)](#módulos-de-negocio-contexts)
6. [Páginas LiveView y Rutas](#páginas-liveview-y-rutas)
7. [Panel Admin](#panel-admin)
8. [Panel SysAdmin](#panel-sysadmin)
9. [Tienda (Storefront)](#tienda-storefront)
10. [Integración API Frog](#integración-api-frog)
11. [Imágenes y SFTP](#imágenes-y-sftp)
12. [Base de Datos](#base-de-datos)
13. [JavaScript Hooks](#javascript-hooks)
14. [Levantar el Proyecto](#levantar-el-proyecto)

---

## Stack Técnico

| Capa | Tecnología |
|---|---|
| Lenguaje | Elixir ~1.15 |
| Framework | Phoenix ~1.8 + Phoenix LiveView ~1.1 |
| Base de datos | PostgreSQL (driver Postgrex) |
| CSS | Tailwind CSS |
| Build JS | esbuild |
| HTTP Client | Req ~0.5 |
| Excel | elixlsx |
| Email | Swoosh + gen_smtp |
| SFTP | Erlang `:ssh` (built-in) |
| Mapas | Google Maps API (JS hook) |
| Hosting imágenes | Servidor SFTP propio → URL pública prettycore.xyz |

---

## Arquitectura General

```
┌────────────────────────────────────────────────────────────────────┐
│                        PRETTYCORE                                  │
│                                                                    │
│  ┌──────────────┐   ┌──────────────────┐   ┌──────────────────┐    │
│  │  /sysadmin   │   │   /admin/**      │   │  Tienda (store)  │    │
│  │  SysAdmin    │   │   Panel Admin    │   │  (vía /admin/    │    │
│  │  panel       │   │   (admins/       │   │   tienda)        │    │
│  │              │   │    oficina)      │   │                  │    │
│  └──────┬───────┘   └────────┬─────────┘   └────────┬─────────┘    │
│         │                    │                       │             │
│         └────────────────────┴───────────────────────┘             │
│                              │                                     │
│                    ┌─────────▼─────────┐                           │
│                    │  Business Contexts │                          │
│                    │  Pedidos, Carrito  │                          │
│                    │  Productos, Auth   │                          │
│                    │  Secciones, etc.   │                          │
│                    └─────────┬─────────┘                           │
│                              │                                     │
│              ┌───────────────┼───────────────┐                     │
│              │               │               │                     │
│     ┌────────▼───┐  ┌────────▼───┐  ┌───────▼──────┐               │
│     │ PostgreSQL │  │  Frog API  │  │  SFTP Server │               │
│     │ (PsqlRepo) │  │  (Frog ERP)│  │ (imágenes)   │               │
│     └────────────┘  └────────────┘  └──────────────┘               │
└────────────────────────────────────────────────────────────────────┘
```

El sistema opera en dos modos configurables desde SysAdmin:

- **Modo Nativo** (`modo_nativo = true`): Solo usa datos propios de PostgreSQL. Productos nativos, clientes nativos, precios y stock gestionados internamente. Sin dependencia de la API Frog.
- **Modo API Frog** (`modo_nativo = false`): Conecta con el ERP Frog para sincronizar productos, clientes, direcciones y precios. El panel admin actúa como capa de configuración encima del ERP.

---

## Perfiles de Usuario (Roles)

### `sysadmin`
Acceso exclusivo al panel `/sysadmin`. Es el **único perfil con poder para eliminar usuarios**. Puede hacer todo lo que hace admin más:
- Configurar credenciales de la API Frog (URL, token, usuario, instancia)
- Activar/desactivar modo nativo
- Configurar la banda de publicidad (texto y color)
- Ver y cerrar forzosamente sesiones de cualquier usuario
- Crear, editar y eliminar usuarios del sistema
- Asignar/revocar permisos granulares a cada usuario
- Acceder al dashboard de inteligencia/analytics

### `admin`
Acceso completo al panel `/admin`. Gestiona toda la operación de la tienda:
- Productos nativos (CRUD + imágenes)
- Categorías y super-categorías
- Carrusel de imágenes
- Secciones de la tienda (top10, favoritos, destacados, ofertas, publicidad, envíos)
- Pedidos: visualizar y cambiar estado
- Clientes Frog (solo lectura) y clientes nativos (CRUD)
- Listas de precios
- Sucursales y stock por sucursal
- Usuarios: puede crear, editar y **solo inactivar** (no eliminar). La eliminación está reservada exclusivamente para `sysadmin`

### `oficina`
Mismo acceso que admin. Orientado a personal de sucursal u oficina. En la tienda aparece como "Solo inspección" (puede ver pero no puede agregar al carrito).

### `user`
Usuario estándar del sistema con permisos individuales configurables. Solo ve las secciones para las que tiene permiso (inicio, tienda, pedidos, clientes, etc.). Puede navegar la tienda, agregar al carrito y hacer pedidos.

### `cliente_nativo`
Cliente B2B/B2C creado directamente en Prettycore (no en Frog). Se autentica con email/contraseña propia. Tiene asignado:
- Una **lista de precios** (número) → ve los precios de su lista
- Una **sucursal** (`sucursal_numero`) → ve el stock de su sucursal
- Puede navegar la tienda, agregar al carrito y generar pedidos

---

## Autenticación y Sesiones

### Doble autenticación
- **Usuarios del sistema** (`users` table): admin, oficina, sysadmin, user
- **Clientes nativos** (`clientes_nativos` table): clientes B2B registrados directamente

Ambos tipos autentican en el mismo formulario de login (`/`). El sistema detecta automáticamente en cuál tabla buscar.

### Seguridad
- Contraseñas hasheadas con **PBKDF2-SHA512** (160,000 iteraciones, estándar OWASP)
- Sessions almacenadas en cookie firmada + tabla `users_sessions` en BD
- Cada sesión registra: IP, tipo de dispositivo, navegador, SO, `last_seen_at`, `logged_out_at`
- Soporte para cerrar sesiones forzosamente desde el panel SysAdmin

### Password Reset
- Flujo de 3 pasos en LiveView: solicitar → verificar código → nueva contraseña
- Código de 6 dígitos con expiración de 30 minutos (almacenado en ETS)
- Envío por email vía Swoosh

### Guards de ruta
- `:auth` live_session → verifica que haya `user_id` en sesión, carga rol y permisos
- `:sysadmin` live_session → verifica adicionalmente que `role == "sysadmin"`
- Redirección automática: sin sesión → `/`, sysadmin → `/sysadmin`, otros → `/admin/platform`

---

## Módulos de Negocio (Contexts)

### `Prettycore.Auth`
Gestión de usuarios del sistema. Login, logout, password reset, creación de sesiones, detección de dispositivo/navegador por User-Agent, consulta de sesiones activas, cierre forzoso.

### `Prettycore.ClientesNativos`
CRUD de clientes nativos (B2B). Campos: `username`, `email`, `password_hash`, `nombre`, `telefono`, `lista_precios` (número), `sucursal_numero`, `activo`. Incluye autenticación propia integrada con el flujo de login principal.

### `Prettycore.Pedidos`
Ciclo de vida de órdenes:
```
pendiente → procesando → enviado → entregado
                                 ↘ cancelado
                 ← cancelacion_solicitada (cliente pide, admin aprueba)
```
Cada pedido tiene `PedidoItem` con: `producto_codigo`, `descripcion`, `cantidad`, `precio_unitario`. Admins ven todos los pedidos; clientes ven solo los suyos.

### `Prettycore.Carritos`
Carrito persistente en BD por `user_id`. Operaciones: agregar ítem, quitar ítem, actualizar cantidad, vaciar carrito, convertir a pedido. Los ítems se enriquecen con datos de `ProductosNativos` o `Productos` (Frog).

### `Prettycore.ProductosNativos`
Productos creados directamente en Prettycore. Campos: `codigo` (PROD-NNN auto-generado), `descripcion`, `desc_corta`, `marca`, `precio_base`, `stock`, `unidad`, `notas`, `categoria`, `super_categoria`, `activo`, `imagen_url`. Imagen subida vía SFTP con cache-buster en URL.

### `Prettycore.Categorias`
Categorías simples para agrupar productos. La categoría "Inicio" está protegida (no se puede eliminar). Orden configurable via drag-and-drop. Imagen subida vía SFTP.

### `Prettycore.SuperCategorias`
Categorías de nivel superior que agrupan múltiples productos via tabla join `super_categoria_productos`. También tienen imagen SFTP y orden.

### `Prettycore.Carrusel`
Imágenes del banner rotatorio en la tienda. Campos: `filename`, `url`, `orden`, `activo`. Reordenables vía drag-and-drop. Activar/desactivar individualmente.

### `Prettycore.Secciones`
8 secciones configurables del storefront: `carrusel`, `productos`, `favoritos`, `publicidad`, `destacados`, `envios`, `top10`, `ofertas`. Cada sección tiene `nombre`, `orden`, `activo`, `config` (JSON). El admin puede cambiar visibilidad, orden y nombre.

### `Prettycore.ListasPrecios`
Precios por lista numerada. Clave compuesta: `(numero, producto_codigo)`. Los clientes nativos tienen asignado un `lista_precios` número y ven solo los precios de esa lista.

### `Prettycore.Sucursales`
Gestión de sucursales físicas. Campos: `numero` (identificador), `nombre`, `direccion`, `activo`. Los clientes nativos se asignan a una sucursal.

### `Prettycore.StockSucursal`
Stock por sucursal. Clave compuesta: `(sucursal_numero, producto_codigo)`. Los admins actualizan cantidades desde el panel Stock. Los clientes ven el stock de su sucursal asignada.

### `Prettycore.SysAdmin`
Configuración global del sistema (singleton id=1):
- Credenciales de la API Frog
- `modo_nativo` (boolean)
- `banda_texto` y `banda_color` para el banner publicitario
- `permitir_edicion` (habilitar/deshabilitar edición)
- Configuración cacheada 5 minutos en `persistent_term`

### `Prettycore.Sftp`
Módulo de subida de imágenes vía SSH/SFTP. Directorios separados por tipo (`/PRODUCTOS`, `/CATEGORIAS`, `/CARRUSEL`, `/SUPERCATEGORIAS`, `/PRODUCTOS_NATIVOS`). Auto-retry hasta 2 intentos. Retorna URL pública o error. Elimina archivos por URL pública.

---

## Páginas LiveView y Rutas

### Públicas
| Ruta | Módulo | Descripción |
|---|---|---|
| `GET /` | `LoginLive` | Formulario de login. Detecta usuarios sistema y clientes nativos |
| `GET /password-reset` | `PasswordResetLive` | Reset de contraseña (3 pasos en LiveView) |
| `GET /logout` | `SessionController` | Cierra sesión y redirige a `/` |
| `GET /health` | `HealthController` | Healthcheck JSON (sin auth) |

### Panel Admin (`/admin/**`, requiere sesión)
| Ruta | Descripción |
|---|---|
| `/admin/platform` | Dashboard de inicio con accesos rápidos |
| `/admin/tienda` | Storefront (vista completa de la tienda) |
| `/admin/pedidos` | Lista y gestión de pedidos |
| `/admin/clientes` | Clientes Frog (solo lectura) |
| `/admin/clientes/new` | Crear cliente (con tabs) |
| `/admin/clientes/edit/:id` | Editar cliente (tabs: perfil, contacto, precios, stock) |
| `/admin/clientes-nativos` | CRUD clientes nativos |
| `/admin/productos-nativos` | CRUD productos nativos + imágenes SFTP |
| `/admin/listas-precios` | Gestión de listas de precios |
| `/admin/categorias` | CRUD categorías + asignación de productos |
| `/admin/super-categorias` | CRUD super-categorías |
| `/admin/categorias-nativas` | Categorías y super-categorías nativas unificadas |
| `/admin/carrusel` | Gestión del carrusel de imágenes |
| `/admin/secciones` | Configuración de secciones del storefront |
| `/admin/seccion/:tipo` | Editor de sección específica (top10, favoritos, etc.) |
| `/admin/sucursales` | CRUD sucursales |
| `/admin/stock` | Stock por sucursal |
| `/admin/usuarios` | CRUD usuarios del sistema + permisos |
| `/admin/clientes/export/excel` | Exportar clientes a Excel (descarga directa) |

### Panel SysAdmin (`/sysadmin/**`, requiere `role=sysadmin`)
| Ruta | Descripción |
|---|---|
| `/sysadmin/configuracion` | Config global: API Frog, modo nativo, banda publicitaria |
| `/sysadmin/sesiones` | Ver y cerrar sesiones activas |
| `/sysadmin/intelligence` | Dashboard de analytics |
| `/sysadmin/usuarios` | CRUD usuarios + permisos granulares |
| `/sysadmin/tienda` | Vista del storefront (inspección) |

---

## Panel Admin

### Gestión de Productos Nativos
- CRUD completo con modal de edición lateral
- Generación automática de código `PROD-NNN`
- Subida de imagen con compresión en cliente (máx 1200px, JPEG 82%) → SFTP
- Asignación a categoría y super-categoría
- Toggle activo/inactivo
- Búsqueda por código o descripción

### Gestión de Categorías
- CRUD con imagen SFTP
- Asignación de productos en bulk
- Reordenamiento via drag-and-drop
- Categoría "Inicio" protegida contra eliminación

### Carrusel
- Subida de imágenes al SFTP
- Reordenar posición via drag-and-drop
- Activar/desactivar cada imagen
- Vista previa en lista

### Secciones
- Lista de 7 secciones predeterminadas con toggle de visibilidad
- Reordenamiento
- Editor específico por tipo de sección:
  - `top10`, `favoritos`, `destacados`: editor individual con selector de productos, título y color de fondo
  - `ofertas` (Top 10, Destacados y Favs): carrusel combinado — sube imágenes de publicidad al FTP (carpeta `CARRUSEL_DESTACADOS`), las mezcla con las secciones top10/favoritos/destacados, y permite reordenar todo. En tienda se muestran en contenedores del mismo tamaño que los de productos (`aspect-ratio: 0.87`, `object-cover`)
  - `publicidad`: editor de carrusel maestro (slides de imágenes + secciones de productos ordenables)
  - `envios`: configuración de información de envíos
  - Cada sección se configura de forma independiente

### Pedidos
- Lista completa con estado coloreado
- Filtro por búsqueda: número de pedido, sucursal, teléfono, correo
- Vista de detalle con todos los ítems, cliente, precios
- Cambio de estado (admin): pendiente → procesando → enviado → entregado → cancelado
- Aprobación de solicitudes de cancelación del cliente

### Stock por Sucursal
- Selector de sucursal
- Tabla de todos los productos con cantidad editable
- Búsqueda por código o descripción
- Guardado en lote

### Clientes Nativos
- CRUD completo (crear, editar, eliminar, buscar)
- Asignación de lista de precios y sucursal
- Copia rápida de email/teléfono al portapapeles
- Toggle activo/inactivo

---

## Panel SysAdmin

### Configuración del Sistema
- **Modo Nativo**: Toggle para desconectar la API Frog y operar solo con datos nativos
- **Credenciales Frog**: URL, token, usuario, instancia. Test de conexión antes de guardar (llama a `SYS_EMPRESA` y muestra la respuesta JSON)
- **Banda de Publicidad**:
  - Preview en tiempo real mientras se edita
  - Campo de texto (máx 200 chars)
  - Color picker nativo + campo hex manual
  - Se aplica automáticamente en el banner marquee del panel admin
- **Campos ocultos**: Al guardar en modo nativo, los campos de API se preservan en `<input type="hidden">` para no borrarlos accidentalmente

### Sesiones
- Tabla de todas las sesiones activas del sistema
- Información por sesión: usuario, IP, dispositivo, navegador, SO, última actividad
- Cerrar sesión individual (invalida el token)
- Cerrar todas las sesiones activas a la vez

### Usuarios
- Crear usuarios con rol (admin, oficina, user)
- Editar email, usuario_frog, cliente_codigo, dir_codigo
- Toggle activo/inactivo
- Panel de permisos expandible por usuario:
  - inicio, tienda, pedidos, clientes, productos, categorias, administrar, etc.
  - Toggle individual por permiso
- Eliminación (no aplica a sysadmin)

---

## Tienda (Storefront)

La tienda es accesible desde `/admin/tienda` y `/sysadmin/tienda`. La ven tanto administradores (en modo inspección) como clientes nativos autenticados.

### Navegación por Categorías
- Carrusel vertical infinito con las categorías activas
- Navegación con scroll del mouse (throttled 320ms) y swipe táctil en móvil
- La categoría activa se centra automáticamente (smooth scroll)
- Al llegar al final, hace loop invisible de vuelta al inicio (efecto infinito estilo McDonald's)

### Carrusel de Banner
- Rotación automática cada 4 segundos
- Flechas prev/next
- Puntos indicadores de posición
- Scroll táctil en móvil

### Productos
- Grid de productos con imagen, nombre, precio y stock
- Precios: muestra el precio de la lista asignada al cliente; si no hay lista, muestra `precio_base`
- Stock: muestra el stock de la sucursal asignada al cliente (o stock global si no hay sucursal)
- Productos "Agotado" se marcan en rojo sin botón de compra
- Botón "Agregar" (con ícono carrito) para agregar al carrito
- Modo inspección (admin/oficina): botón deshabilitado con label "Solo inspección"

### Carrito
- Panel lateral deslizable
- Agregar/quitar ítems, cambiar cantidades
- Subtotal calculado con precios de lista
- Botón "Vaciar carrito"
- Botón "Realizar pedido" → convierte carrito a Pedido en BD → limpia carrito → flash de confirmación

### Búsqueda
- Busca en tiempo real por descripción, código o marca
- Se combina con el filtro de categoría activo

### Banda Publicitaria
- Banner marquee en la parte superior con texto e color configurables desde SysAdmin
- Si no hay configuración guardada, muestra valor por defecto (texto y color indigo)

---

## Integración API Frog

Cuando `modo_nativo = false`, Prettycore actúa como capa sobre el ERP Frog.

### Autenticación con Frog
1. El usuario tiene `usuario_frog` asignado en su perfil
2. El sistema envía ese usuario al endpoint `/REST_USUARIO`
3. La API devuelve `SYSUSR_PASSWORD` (token de sesión Frog)
4. Ese token se usa para llamadas posteriores

### Endpoints utilizados
| Tabla Frog | Uso |
|---|---|
| `PRO_PRODUCTO` | Sincronizar catálogo de productos |
| `CTE_CLIENTE` | Leer datos de clientes |
| `CTE_DIRECCION` | Leer direcciones de entrega |
| `VTA_PRECIOS` | Obtener precios por cliente y lista |
| `Estadisticas` | Ventas, cuentas por cobrar, historial |
| `SYS_USUARIO` | Usuarios del ERP |
| `XEN_WOKORDERENC/DET` | Órdenes de trabajo |
| `MAP_ESTADO/MUNICIPIO` | Catálogos geográficos |

### Caché de configuración
- URL base y token almacenados en `persistent_term` con TTL de 5 minutos
- Se invalida al guardar nueva configuración en SysAdmin

---

## Imágenes y SFTP

### Flujo de subida
1. Usuario selecciona imagen en el formulario
2. **ImageCompressor** (JS hook, capture phase):
   - Si el archivo pesa > 250 KB: redimensiona a máx 1200px, convierte a JPEG 82%
   - Genera data URL de preview y dispara evento `image-preview-ready`
   - Reemplaza el archivo en el input con el archivo comprimido
3. LiveView detecta el archivo y crea una entrada en `@uploads.imagen.entries`
4. Al hacer click en "Guardar", `consume_uploaded_entries` lee el archivo temporal
5. El servidor sube el binario via SFTP al servidor
6. El servidor retorna la URL pública
7. La URL se guarda en la BD con un **cache-buster** (`?v=timestamp`) para forzar refresco en navegadores

### Estructura de directorios SFTP
```
prettycore.xyz/ELIXIR/PRETTYCORE/
├── PRODUCTOS/           → Productos de la API Frog
├── CATEGORIAS/          → Imágenes de categorías
├── SUPERCATEGORIAS/     → Imágenes de super-categorías
├── CARRUSEL/            → Imágenes del banner carrusel
└── PRODUCTOS_NATIVOS/   → Imágenes de productos nativos
```

### Convención de nombres
- Productos nativos: `{CODIGO}.jpg` (ej. `PROD-004.jpg`)
- Carrusel: nombre de archivo original preservado
- Categorías: `{nombre-slug}.jpg`

---

## Base de Datos

### Tablas principales

| Tabla | Descripción |
|---|---|
| `users` | Usuarios del sistema (admin, oficina, sysadmin, user) |
| `users_sessions` | Sesiones activas con metadata de dispositivo |
| `clientes_nativos` | Clientes B2B creados directamente |
| `pedidos` | Órdenes de compra |
| `pedido_items` | Ítems de cada pedido |
| `carritos` | Carritos de compra activos |
| `carrito_items` | Ítems en el carrito |
| `productos` | Productos sincronizados desde la API Frog |
| `productos_nativos` | Productos creados directamente en Prettycore |
| `categorias` | Categorías de productos |
| `categoria_productos` | Join: categoría ↔ producto |
| `super_categorias` | Super-categorías de nivel superior |
| `carrusel_imagenes` | Imágenes del banner rotatorio |
| `secciones` | Configuración de secciones del storefront |
| `clientes_nativos` | Clientes B2B nativos |
| `listas_precios` | Precios por lista numerada y producto |
| `sucursales` | Sucursales físicas |
| `stock_sucursal` | Stock por sucursal y producto |
| `system_config` | Configuración global del sistema (singleton id=1) |
| `client_intelligence` | Datos de analytics/inteligencia de clientes |

### `system_config` (singleton)
```
id                  integer  (siempre 1)
usuario             string   (usuario API Frog)
instancia           string   (URL instancia Frog)
token               string   (Bearer token Frog)
url                 string   (URL pública de la app)
foto                string   (logo de la empresa)
permitir_edicion    boolean  (habilitar edición en paneles)
modo_nativo         boolean  (true = sin Frog API)
banda_texto         string   (texto del banner publicitario)
banda_color         string   (color hex del banner, ej. #4f46e5)
```

---

## JavaScript Hooks

Todos definidos en `assets/js/app.js` y registrados en `LiveSocket`:

| Hook | Elemento | Descripción |
|---|---|---|
| `ImageCompressor` | `<input type="file">` | Comprime imágenes en cliente antes de subir. Captura el evento `change`, redimensiona a máx 1200px, convierte a JPEG 82%. Genera data URL de preview. |
| `ImagePreview` | `<img>` | Escucha el evento `image-preview-ready` y actualiza su `src` con la data URL generada por ImageCompressor. Usa `phx-update="ignore"` para que LiveView no sobreescriba el src. |
| `ScrollCatActive` | Contenedor de categorías | Carrusel vertical infinito. Scroll de mouse throttled (320ms), swipe táctil. Centra la categoría activa. Loop invisible al llegar al extremo. |
| `Carrusel` | Contenedor de carrusel | Auto-play cada 4s, flechas prev/next, scroll táctil. Actualiza puntos indicadores. |
| `DragSort` | Listas reordenables | Drag-and-drop nativo (HTML5 Drag API). Calcula nueva posición por cursor y emite evento `reorder` con el nuevo orden de IDs. |
| `LocationMap` | `<div>` mapa | Integración con Google Maps API. Carga el script dinámicamente, renderiza mapa interactivo con marcador arrastrable. Al mover el marcador, actualiza inputs `map_x`/`map_y` y emite `update_coordinates`. |
| `NavigateAfterFlash` | LiveView root | Escucha evento `navigate-after-flash` y hace redirect con delay configurable. |
| `AutoFlash` | Flash message | Auto-oculta el flash con animación después de 3 segundos. |
| `TiendaSync` | LiveView root | Persiste estado de sincronización entre navegaciones (estado en `window`, sobrevive push_navigate pero se limpia al recargar). |

---

## Levantar el Proyecto

### Requisitos
- Elixir >= 1.15
- Erlang/OTP >= 26
- PostgreSQL >= 14
- Node.js (para assets, solo en desarrollo)

### Variables de entorno
```bash
DB_HOSTNAME_PSQL=localhost
DB_PORT_PSQL=5432
DB_USERNAME_PSQL=postgres
DB_PASSWORD_PSQL=postgres
DB_NAME_PSQL=prettycore
SECRET_KEY_BASE=<clave generada con mix phx.gen.secret>
```

### Instalación
```bash
# Instalar dependencias
mix setup

# Correr migraciones
mix ecto.migrate --repo Prettycore.PsqlRepo

# Crear usuario sysadmin inicial
mix seed.sysadmin

# Iniciar servidor de desarrollo
mix phx.server
```

Visitar: [http://localhost:4000](http://localhost:4000)

### Producción
```bash
mix assets.deploy
MIX_ENV=prod mix phx.server
```

Ver guía de despliegue: [https://hexdocs.pm/phoenix/deployment.html](https://hexdocs.pm/phoenix/deployment.html)
