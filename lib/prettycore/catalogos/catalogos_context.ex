# lib/prettycore/catalogos/catalogos_context.ex
defmodule Prettycore.Catalogos.CatalogosContext do
  # Importar subcontextos
  alias Prettycore.Catalogos.Productos.ProductosContext
  alias Prettycore.Catalogos.Clientes.ClientesContext

  # ========== DELEGAR A PRODUCTOS ==========
  defdelegate listar_productos, to: ProductosContext
  defdelegate listar_productos(offset, limit), to: ProductosContext
  defdelegate count_productos, to: ProductosContext
  defdelegate obtener_producto(id), to: ProductosContext
  defdelegate crear_producto(attrs), to: ProductosContext
  defdelegate actualizar_producto(producto, attrs), to: ProductosContext
  defdelegate buscar_producto(id), to: ProductosContext

  # ========== DELEGAR A CLIENTES ==========
  defdelegate listar_clientes, to: ClientesContext
  defdelegate listar_clientes(offset, limit), to: ClientesContext
  defdelegate count_clientes, to: ClientesContext
  defdelegate obtener_cliente(id), to: ClientesContext
  defdelegate buscar_cliente(id), to: ClientesContext
  defdelegate crear_cliente(attrs), to: ClientesContext
  defdelegate actualizar_cliente(cliente, attrs), to: ClientesContext
end
