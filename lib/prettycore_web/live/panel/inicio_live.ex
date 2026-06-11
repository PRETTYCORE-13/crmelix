defmodule PrettycoreWeb.Inicio do
  use PrettycoreWeb, :live_view_admin

  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: "/admin/disenador")}
  end

  def render(assigns), do: ~H""
end
