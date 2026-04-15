defmodule PrettycoreWeb.SeccionesLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Secciones
  alias Prettycore.Secciones.Seccion

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_page, "secciones")
      |> assign(:sidebar_open, true)
      |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
      |> assign(:secciones, [])
      |> assign(:editando_id, nil)
      |> assign(:edit_nombre, "")

    if connected?(socket), do: send(self(), :load_secciones)
    {:ok, socket}
  end

  @impl true
  def handle_info(:load_secciones, socket) do
    {:noreply, assign(socket, secciones: Secciones.list_secciones())}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    case id do
      "toggle_sidebar"  -> {:noreply, update(socket, :sidebar_open, &(not &1))}
      "inicio"          -> {:noreply, push_navigate(socket, to: ~p"/admin/platform")}
      "clientes"                   -> {:noreply, update(socket, :show_clientes_children, &(not &1))}
      "clientes_frog"              -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}
      "toggle_prettycore_children" -> {:noreply, update(socket, :show_prettycore_children, &(not &1))}
      "clientes_nativos"           -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes-nativos")}
      "listas_precios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/listas-precios")}
      "lista_productos"            -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "tienda"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}
      "pedidos"                    -> {:noreply, push_navigate(socket, to: ~p"/admin/pedidos")}
      "categorias"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}
      "super_categorias"           -> {:noreply, push_navigate(socket, to: ~p"/admin/super-categorias")}
      "carrusel"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/carrusel")}
      "secciones"                  -> {:noreply, socket}
      "usuarios"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}
      "seccion_top10"              -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_ofertas"            -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/ofertas")}
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      "productos_nativos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "stock"                      -> {:noreply, push_navigate(socket, to: ~p"/admin/stock")}
      "sucursales"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/sucursales")}
      "categorias_nativas"         -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias-nativas")}
      _                            -> {:noreply, socket}
    end
  end

  def handle_event("toggle_activo", %{"id" => id}, socket) do
    sec = Enum.find(socket.assigns.secciones, &(&1.id == id))
    if sec do
      secs = Secciones.toggle_activo(sec)
      {:noreply, assign(socket, secciones: secs)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_grupo_promo", _, socket) do
    tipos_promo = ["top10", "favoritos", "destacados"]
    promo_secs = Enum.filter(socket.assigns.secciones, &(&1.tipo in tipos_promo))
    todas_activas = Enum.all?(promo_secs, & &1.activo)
    nuevo_estado = not todas_activas
    secs = Enum.reduce(promo_secs, [], fn sec, _acc ->
      Secciones.set_activo(sec, nuevo_estado)
    end)
    {:noreply, assign(socket, secciones: secs)}
  end

  def handle_event("reorder", %{"ids" => ids}, socket) do
    secs = Secciones.reorder(ids)
    {:noreply, assign(socket, secciones: secs)}
  end

  def handle_event("mover", %{"gidx" => gidx_str, "dir" => dir}, socket) do
    secs    = socket.assigns.secciones
    groups  = build_groups(secs)
    gidx    = String.to_integer(gidx_str)
    new_gidx = if dir == "up", do: gidx - 1, else: gidx + 1

    if new_gidx >= 0 and new_gidx < length(groups) do
      ga = Enum.at(groups, gidx)
      gb = Enum.at(groups, new_gidx)
      new_ids =
        groups
        |> List.replace_at(gidx, gb)
        |> List.replace_at(new_gidx, ga)
        |> Enum.flat_map(fn
          {:single, sec}    -> [sec.id]
          {:promo,  list}   -> Enum.map(list, & &1.id)
        end)

      {:noreply, assign(socket, secciones: Secciones.reorder(new_ids))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("editar_nombre", %{"id" => id}, socket) do
    sec = Enum.find(socket.assigns.secciones, &(&1.id == id))
    {:noreply, assign(socket, editando_id: id, edit_nombre: sec && sec.nombre || "")}
  end

  def handle_event("guardar_nombre", %{"nombre" => nombre}, socket) do
    sec = Enum.find(socket.assigns.secciones, &(&1.id == socket.assigns.editando_id))
    if sec && String.trim(nombre) != "" do
      secs = Secciones.update_nombre(sec, String.trim(nombre))
      {:noreply, assign(socket, secciones: secs, editando_id: nil, edit_nombre: "")}
    else
      {:noreply, assign(socket, editando_id: nil)}
    end
  end

  def handle_event("cancelar_edicion", _, socket) do
    {:noreply, assign(socket, editando_id: nil, edit_nombre: "")}
  end


  # ── Render ────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :groups, build_groups(assigns.secciones))
    ~H"""
    <div class="flex min-h-screen bg-gray-100">

      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />

      <!-- ══ CONTENIDO PRINCIPAL ══ -->
      <section class="flex-1 p-4 sm:p-6 min-w-0">
        <header class="mb-5">
          <h1 class="text-2xl font-bold text-gray-900">Secciones de la Tienda</h1>
          <p class="text-sm text-gray-500 mt-0.5">Activa y ordena los bloques que aparecen en la tienda</p>
        </header>

        <div class="space-y-2">
          <%= for {group, gi} <- Enum.with_index(@groups) do %>
            <% total_groups = length(@groups) %>

            <%= if match?({:promo, _}, group) do %>
              <% {:promo, promo_secs} = group %>
              <% todas_activas = Enum.all?(promo_secs, & &1.activo) %>
              <% alguna_activa = Enum.any?(promo_secs, & &1.activo) %>

              <div class={"group flex items-stretch gap-0 rounded-2xl border overflow-hidden transition-all select-none #{if alguna_activa, do: "bg-white border-gray-200 shadow-sm", else: "bg-gray-50 border-gray-100"}"}>
                <!-- Columna izquierda: flechas + posición -->
                <div class="flex flex-col items-center justify-center bg-gray-50 border-r border-gray-100 px-2 py-3 gap-1 min-w-[44px]">
                  <button phx-click="mover" phx-value-gidx={gi} phx-value-dir="up"
                    disabled={gi == 0}
                    class={"w-7 h-7 rounded-lg flex items-center justify-center transition-all #{if gi == 0, do: "text-gray-200 cursor-not-allowed", else: "text-gray-400 hover:bg-purple-100 hover:text-purple-600 active:scale-95"}"}>
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7"/>
                    </svg>
                  </button>
                  <span class="text-[11px] font-bold text-gray-400 leading-none"><%= gi + 1 %></span>
                  <button phx-click="mover" phx-value-gidx={gi} phx-value-dir="down"
                    disabled={gi == total_groups - 1}
                    class={"w-7 h-7 rounded-lg flex items-center justify-center transition-all #{if gi == total_groups - 1, do: "text-gray-200 cursor-not-allowed", else: "text-gray-400 hover:bg-purple-100 hover:text-purple-600 active:scale-95"}"}>
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                    </svg>
                  </button>
                </div>

                <!-- Contenido -->
                <div class="flex flex-1 items-center gap-3 px-3 py-4 min-w-0">
                  <div class="flex-shrink-0 px-2 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wide bg-red-100 text-red-700">Ofertas</div>
                  <div class="flex-1 min-w-0">
                    <span class={"text-sm font-semibold #{if alguna_activa, do: "text-gray-900", else: "text-gray-400"}"}>Carrusel de Ofertas</span>
                    <div class="flex flex-wrap gap-1 mt-1">
                      <%= for ps <- promo_secs do %>
                        <button phx-click="toggle_activo" phx-value-id={ps.id}
                          class={"text-[10px] px-1.5 py-0.5 rounded font-medium transition-colors #{if ps.activo, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-400"}"}>
                          <%= ps.nombre %>
                        </button>
                      <% end %>
                    </div>
                    <p class={"text-xs font-medium mt-0.5 #{if alguna_activa, do: "text-green-600", else: "text-gray-400"}"}><%= if alguna_activa, do: "✓ Visible en tienda", else: "Oculta" %></p>
                  </div>
                  <button phx-click="toggle_grupo_promo"
                    class={"flex-shrink-0 relative inline-flex h-7 w-12 items-center rounded-full transition-colors focus:outline-none #{if todas_activas, do: "bg-purple-600", else: "bg-gray-200"}"}>
                    <span class={"inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform #{if todas_activas, do: "translate-x-6", else: "translate-x-1"}"}></span>
                  </button>
                </div>
              </div>

            <% else %>
              <% {:single, sec} = group %>

              <div class={"group flex items-stretch gap-0 rounded-2xl border overflow-hidden transition-all select-none #{if sec.activo, do: "bg-white border-gray-200 shadow-sm", else: "bg-gray-50 border-gray-100"}"}>
                <!-- Columna izquierda: flechas + posición -->
                <div class="flex flex-col items-center justify-center bg-gray-50 border-r border-gray-100 px-2 py-3 gap-1 min-w-[44px]">
                  <button phx-click="mover" phx-value-gidx={gi} phx-value-dir="up"
                    disabled={gi == 0}
                    class={"w-7 h-7 rounded-lg flex items-center justify-center transition-all #{if gi == 0, do: "text-gray-200 cursor-not-allowed", else: "text-gray-400 hover:bg-purple-100 hover:text-purple-600 active:scale-95"}"}>
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7"/>
                    </svg>
                  </button>
                  <span class="text-[11px] font-bold text-gray-400 leading-none"><%= gi + 1 %></span>
                  <button phx-click="mover" phx-value-gidx={gi} phx-value-dir="down"
                    disabled={gi == total_groups - 1}
                    class={"w-7 h-7 rounded-lg flex items-center justify-center transition-all #{if gi == total_groups - 1, do: "text-gray-200 cursor-not-allowed", else: "text-gray-400 hover:bg-purple-100 hover:text-purple-600 active:scale-95"}"}>
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                    </svg>
                  </button>
                </div>

                <!-- Contenido -->
                <div class="flex flex-1 items-center gap-3 px-3 py-4 min-w-0">
                  <div class={"flex-shrink-0 px-2 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wide #{tipo_color(sec.tipo)}"}>
                    <%= Seccion.tipo_label(sec.tipo) %>
                  </div>
                  <div class="flex-1 min-w-0">
                    <%= if @editando_id == sec.id do %>
                      <form phx-submit="guardar_nombre" class="flex items-center gap-2">
                        <input type="text" name="nombre" value={@edit_nombre} autofocus
                          class="flex-1 px-2 py-1 border border-purple-400 rounded-lg text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
                        <button type="submit" class="px-2 py-1 bg-purple-600 text-white rounded-lg text-xs font-medium hover:bg-purple-500">OK</button>
                        <button type="button" phx-click="cancelar_edicion" class="px-2 py-1 text-gray-500 hover:text-gray-700 text-xs">✕</button>
                      </form>
                    <% else %>
                      <div class="flex items-center gap-1.5">
                        <span class={"text-sm font-semibold #{if sec.activo, do: "text-gray-900", else: "text-gray-400"}"}><%= sec.nombre %></span>
                        <button phx-click="editar_nombre" phx-value-id={sec.id} class="p-0.5 text-gray-300 hover:text-purple-500 transition-colors opacity-0 group-hover:opacity-100">
                          <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                          </svg>
                        </button>
                      </div>
                      <p class={"text-xs font-medium mt-0.5 #{if sec.activo, do: "text-green-600", else: "text-gray-400"}"}><%= if sec.activo, do: "✓ Visible en tienda", else: "Oculta" %></p>
                    <% end %>
                  </div>
                  <button phx-click="toggle_activo" phx-value-id={sec.id}
                    class={"flex-shrink-0 relative inline-flex h-7 w-12 items-center rounded-full transition-colors focus:outline-none #{if sec.activo, do: "bg-purple-600", else: "bg-gray-200"}"}>
                    <span class={"inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform #{if sec.activo, do: "translate-x-6", else: "translate-x-1"}"}></span>
                  </button>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </section>

    </div>
    """
  end


  defp tipo_color("carrusel"),   do: "bg-indigo-100 text-indigo-700"
  defp tipo_color("productos"),  do: "bg-blue-100 text-blue-700"
  defp tipo_color("top10"),      do: "bg-yellow-100 text-yellow-700"
  defp tipo_color("favoritos"),  do: "bg-red-100 text-red-700"
  defp tipo_color("destacados"), do: "bg-orange-100 text-orange-700"
  defp tipo_color("publicidad"), do: "bg-purple-100 text-purple-700"
  defp tipo_color("envios"),     do: "bg-green-100 text-green-700"
  defp tipo_color(_),            do: "bg-gray-100 text-gray-700"

  # Agrupa las secciones promo (top10/favoritos/destacados) en un solo bloque.
  # Devuelve lista de {:single, sec} | {:promo, [sec, ...]}
  defp build_groups(secs) do
    tipos_promo = MapSet.new(["top10", "favoritos", "destacados"])

    {groups, pending} =
      Enum.reduce(secs, {[], nil}, fn sec, {acc, promo_acc} ->
        if sec.tipo in tipos_promo do
          {acc, (promo_acc || []) ++ [sec]}
        else
          acc = if promo_acc, do: acc ++ [{:promo, promo_acc}], else: acc
          {acc ++ [{:single, sec}], nil}
        end
      end)

    if pending, do: groups ++ [{:promo, pending}], else: groups
  end
end
