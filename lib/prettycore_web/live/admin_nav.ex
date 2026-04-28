defmodule PrettycoreWeb.AdminNav do
  @moduledoc """
  Handler centralizado de navegación admin.
  Un solo lugar para mantener todas las rutas del menú lateral.
  """

  import Phoenix.LiveView, only: [push_navigate: 2]
  import Phoenix.Component, only: [update: 3]

  @routes %{
    "inicio"             => "/admin/tienda",
    "clientes_frog"      => "/admin/clientes",
    "clientes_nativos"   => "/admin/clientes-nativos",
    "listas_precios"     => "/admin/listas-precios",
    "gamas"              => "/admin/gamas",
    "lista_productos"    => "/admin/productos-nativos",
    "productos_nativos"  => "/admin/productos-nativos",
    "stock"              => "/admin/stock",
    "sucursales"         => "/admin/sucursales",
    "categorias_nativas" => "/admin/categorias-nativas",
    "tienda"             => "/admin/tienda",
    "pedidos"            => "/admin/pedidos",
    "categorias"         => "/admin/categorias",
    "super_categorias"   => "/admin/super-categorias",
    "carrusel"           => "/admin/carrusel",
    "secciones"          => "/admin/secciones",
    "usuarios"           => "/admin/usuarios",
    "seccion_ofertas"    => "/admin/seccion/ofertas",
    "seccion_publicidad" => "/admin/seccion/publicidad",
    "seccion_envios"     => "/admin/seccion/envios",
  }

  @doc """
  Maneja el evento change_page. `current_page` es el atom/string de la página actual
  para evitar navegar a la misma URL (causaría remount).
  """
  def handle_nav(id, socket, current_page \\ nil) do
    case id do
      "toggle_sidebar" ->
        {:noreply, update(socket, :sidebar_open, &(not &1))}

      "clientes" ->
        {:noreply, update(socket, :show_clientes_children, &(not &1))}

      "toggle_prettycore_children" ->
        {:noreply, update(socket, :show_prettycore_children, &(not &1))}

      page when page == current_page ->
        {:noreply, socket}

      other ->
        case Map.get(@routes, other) do
          nil  -> {:noreply, socket}
          path -> {:noreply, push_navigate(socket, to: path)}
        end
    end
  end
end
