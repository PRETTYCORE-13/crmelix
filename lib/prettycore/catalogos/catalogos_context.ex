# lib/prettycore/catalogos/catalogos_context.ex
defmodule Prettycore.Catalogos.CatalogosContext do
  # Importar subcontextos
  alias Prettycore.Catalogos.Productos.ProductosContext
  alias Prettycore.Catalogos.Clientes.ClientesContext

  # ========== DELEGAR A PRODUCTOS ==========
  defdelegate listar_productos, to: ProductosContext
  defdelegate listar_productos_activos, to: ProductosContext
  defdelegate obtener_producto(id), to: ProductosContext
  defdelegate crear_producto(attrs), to: ProductosContext
  defdelegate buscar_producto(id), to: ProductosContext
  defdelegate listar_categorias, to: ProductosContext
  defdelegate listar_marcas, to: ProductosContext
  defdelegate listar_gamas, to: ProductosContext

  # ========== DELEGAR A CLIENTES ==========
  defdelegate listar_clientes, to: ClientesContext
  defdelegate listar_clientes_activos, to: ClientesContext
  defdelegate obtener_cliente(id), to: ClientesContext
  defdelegate buscar_cliente_por_rfc(rfc), to: ClientesContext
  defdelegate crear_cliente(attrs), to: ClientesContext
  defdelegate listar_direcciones(cliente_id), to: ClientesContext
  defdelegate listar_contactos(cliente_id), to: ClientesContext
  defdelegate listar_tipos_cliente, to: ClientesContext
end
