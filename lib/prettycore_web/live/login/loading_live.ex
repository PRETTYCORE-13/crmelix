defmodule PrettycoreWeb.LoadingLive do
  use PrettycoreWeb, :live_view

  alias Prettycore.Catalogos

  def mount(_params, session, socket) do
    frog_token = session["frog_token"]

    if connected?(socket) do
      # Lanzar precarga en proceso separado y notificar al terminar
      self_pid = self()
      Task.start(fn ->
        Catalogos.precargar_catalogos(frog_token)
        send(self_pid, :preload_done)
      end)
    end

    {:ok, assign(socket, :loading, true)}
  end

  def handle_info(:preload_done, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> push_navigate(to: ~p"/admin/tienda")}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black flex items-center justify-center">
      <div class="text-center">
        <!-- Spinner -->
        <div class="mb-6 flex justify-center">
          <div class="w-16 h-16 border-4 border-white/20 border-t-teal-400 rounded-full animate-spin"></div>
        </div>

        <h1 class="text-2xl font-bold text-white mb-2">Iniciando sistema</h1>
        <p class="text-white/60 text-sm">Cargando catálogos, por favor espere...</p>

        <!-- Barra de progreso animada -->
        <div class="mt-6 w-64 mx-auto bg-white/10 rounded-full h-1.5 overflow-hidden">
          <div class="h-full bg-gradient-to-r from-teal-400 to-emerald-400 rounded-full animate-pulse" style="width: 100%"></div>
        </div>
      </div>
    </div>
    """
  end
end
