# API REST — Prettycore

Documentación de los endpoints del API REST productos de Prettycore.
Todos los endpoints protegidos requieren un **Bearer token** en el header `Authorization`.

---

## Autenticación

### `POST /producto/point/token`

Obtiene un token de acceso usando credenciales de usuario **sysadmin**.
No requiere token previo.

**Body (JSON):**
```json
{
  "usuario": "sysadmin",
  "contrasena": "tu_password"
}
```

**Respuesta exitosa:**
```json
{
  "ok": true,
  "token": "a3f9c2e1d4b8...",
  "tipo": "bearer"
}
```

**Cómo usar el token en las siguientes llamadas:**
```
Authorization: Bearer a3f9c2e1d4b8...
```

> El token se genera una sola vez y se reutiliza. Se guarda en la tabla `api_tokens` de la base de datos.

---

## Productos

### `GET /producto/point/lista`

Lista todos los productos con paginación.

**Headers requeridos:**
```
Authorization: Bearer TU_TOKEN
```

**Query params opcionales:**

| Param   | Tipo    | Default | Descripción                        |
|---------|---------|---------|------------------------------------|
| `page`  | entero  | `1`     | Número de página                   |
| `limit` | entero  | `50`    | Cantidad de productos por página   |

**Ejemplo:**
```
GET /producto/point/lista?page=2&limit=100
```

**Respuesta:**
```json
{
  "ok": true,
  "total": 1500,
  "page": 2,
  "limit": 100,
  "paginas": 15,
  "data": [
    {
      "codigo": "ABC123",
      "descripcion": "Nombre completo del producto",
      "desc_corta": "Nombre corto",
      "marca": "ACME",
      "iva": 16.0,
      "pzas_min": 1,
      "activo": true,
      "imagen_url": "https://..."
    }
  ]
}
```

---

### `GET /producto/point/sku?q=CODIGO`

Busca productos por código (SKU). Soporta búsqueda parcial.

**Ejemplo:**
```
GET /producto/point/sku?q=ABC
```

**Respuesta:**
```json
{
  "ok": true,
  "total": 3,
  "data": [...]
}
```

---

### `POST /producto/point/sku`

Inserta o actualiza uno o varios productos. Si el `codigo` ya existe lo actualiza; si no, lo crea.

**Un solo producto:**
```json
{
  "codigo": "ABC123",
  "descripcion": "Nombre completo",
  "desc_corta": "Nombre corto",
  "marca": "ACME",
  "iva": 16.0,
  "pzas_min_vta": 1,
  "activo": true,
  "imagen_url": "https://..."
}
```

**Varios productos:**
```json
{
  "productos": [
    { "codigo": "ABC123", "descripcion": "Producto 1" },
    { "codigo": "DEF456", "descripcion": "Producto 2" }
  ]
}
```

> Solo `codigo` es obligatorio. Los demás campos son opcionales.

---

### `GET /producto/point/descrip?q=TEXTO`

Busca productos por descripción o descripción corta.

**Ejemplo:**
```
GET /producto/point/descrip?q=silla
```

---

### `POST /producto/point/descrip`

Igual que `POST /producto/point/sku` — inserta o actualiza productos con el mismo formato.

---

## Explicación del código: `lista_producto_point_controller.ex`

```elixir
def index(conn, params) do
```
`conn` es la conexión HTTP (request + response).
`params` es un mapa con los query params que llegaron en la URL (ej. `%{"page" => "2", "limit" => "50"}`).

```elixir
page  = params |> Map.get("page", "1")  |> parse_int(1)

limit = params |> Map.get("limit", "50") |> parse_int(50)
```
Lee `page` y `limit` de los params. Si no vienen, usa `"1"` y `"50"` como default.
`parse_int` convierte el string a entero; si falla o es negativo, usa el default.

```elixir
offset = (page - 1) * limit
```
Calcula desde qué registro empezar. Página 1 → offset 0, página 2 → offset 50, etc.

```elixir
productos = Productos.list_productos_paginado(offset, limit)
total     = Productos.count_productos()
```
Dos queries a la base de datos:
- `list_productos_paginado`: trae solo los productos de esa página (`LIMIT` + `OFFSET`).
- `count_productos`: cuenta el total para saber cuántas páginas hay.

```elixir
data: Enum.map(productos, &format/1)
```
Transforma cada producto (struct de Ecto) en un mapa simple con solo los campos que queremos exponer en el JSON.
`&format/1` es equivalente a escribir `fn mapa_de_productos -> format(mapa_de_productos) end`.

```elixir
defp format(mapa_de_productos) do
  %{ codigo: mapa_de_productos.codigo, ... }
end
```
Convierte el struct `%Producto{}` en un mapa plano. Solo incluye los campos necesarios para la API; oculta campos internos como `raw`, `inserted_at`, `updated_at`.

> **Nota:** En Elixir las variables deben empezar con minúscula. `mapa_de_productos` es una variable; `MapaDeProductos` sería un módulo y causaría un error.

```elixir
defp parse_int(val, default) do
  case Integer.parse(val) do
    {n, _} when n > 0 -> n
    _ -> default
  end
end
```
Intenta convertir un string a entero. Si el valor no es un número válido o es menor/igual a 0, regresa el `default`. Esto protege contra params malformados como `?page=abc`.
