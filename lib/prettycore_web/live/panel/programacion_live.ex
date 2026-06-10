defmodule PrettycoreWeb.Programacion do
  use PrettycoreWeb, :live_view_admin

  import PrettycoreWeb.MenuLayout

  # Recibir el email de /admin/programacion/:email
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, "programacion")
     |> assign(:sidebar_open, true)
     |> assign(:show_programacion_children, true)
     |> assign(:current_path, "/admin/programacion")}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    email = socket.assigns.current_user_email

    case id do
      "toggle_sidebar" ->
        {:noreply, update(socket, :sidebar_open, &(not &1))}

      "inicio" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/platform")}

      "programacion" ->
        {:noreply,
         socket
         |> assign(:current_page, "programacion")
         |> assign(:show_programacion_children, true)}

      "programacion_sql" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/programacion/sql")}

      "workorder" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/workorder")}

      "clientes" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}

  #    "config" ->
  #      {:noreply, push_navigate(socket, to: ~p"/admin/configuracion")}

      _ ->
        {:noreply, socket}
    end
  end

  # -----------------------------------------------------
  # RENDER
  # -----------------------------------------------------
  @impl true
  def render(assigns) do
    ~H"""
    <section>
      <header class="pc-page-header">
        <h1>Programación</h1>

        <p>Sección general de programación. Aquí luego metemos más módulos.</p>

        <p class="pc-small-muted">
          Correo actual: {@current_user_email} <br /> URL actual: {@current_path}
        </p>
      </header>

      <div class="pc-page-card">
        <h2>Programación</h2>

        <p>Página base de Programación, en blanco por ahora.</p>
      </div>
    </section>
    """
  end
end
