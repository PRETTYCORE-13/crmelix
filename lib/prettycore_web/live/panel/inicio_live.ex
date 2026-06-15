defmodule PrettycoreWeb.Inicio do
  use PrettycoreWeb, :live_view_admin

  alias PrettycoreWeb.AdminNav

  def mount(_params, _session, socket) do
    {:ok, socket
      |> assign(:current_page, "inicio")
      |> assign(:sidebar_open, false)
    }
  end

  def handle_event("change_page", params, socket),
    do: AdminNav.handle_nav(params["id"], socket, "inicio")

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-full text-gray-400 text-sm">
      Bienvenido
    </div>
    """
  end
end
