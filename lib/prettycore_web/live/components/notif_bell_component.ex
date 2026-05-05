defmodule PrettycoreWeb.NotifBellComponent do
  use PrettycoreWeb, :live_component
  alias Prettycore.Notificaciones

  def mount(socket) do
    {:ok,
     socket
     |> assign(:open, false)
     |> assign(:notifications, [])
     |> assign(:count, 0)
     |> assign(:_loaded_user, nil)
     |> assign(:_loaded_refresh, -1)}
  end

  def update(assigns, socket) do
    user_id = assigns[:user_id]
    refresh = assigns[:refresh] || 0

    socket =
      if user_id &&
           (socket.assigns._loaded_user != user_id ||
              socket.assigns._loaded_refresh != refresh) do
        notifs = Notificaciones.list_recientes(user_id)
        count  = Notificaciones.count_no_leidas(user_id)

        socket
        |> assign(:notifications, notifs)
        |> assign(:count, count)
        |> assign(:_loaded_user, user_id)
        |> assign(:_loaded_refresh, refresh)
      else
        socket
      end

    {:ok, assign(socket, user_id: user_id)}
  end

  def handle_event("toggle_notif", _, socket) do
    {:noreply, update(socket, :open, &(!&1))}
  end

  def handle_event("cerrar_notif", _, socket) do
    {:noreply, assign(socket, :open, false)}
  end

  def handle_event("marcar_leida", %{"id" => id}, socket) do
    Notificaciones.marcar_leida(id)
    notifs = Notificaciones.list_recientes(socket.assigns.user_id)
    count  = Notificaciones.count_no_leidas(socket.assigns.user_id)
    {:noreply, assign(socket, notifications: notifs, count: count)}
  end

  def handle_event("marcar_todas", _, socket) do
    Notificaciones.marcar_todas_leidas(socket.assigns.user_id)
    notifs = Notificaciones.list_recientes(socket.assigns.user_id)
    {:noreply, assign(socket, notifications: notifs, count: 0)}
  end

  def render(assigns) do
    ~H"""
    <div class="relative flex items-center">
      <button
        phx-click="toggle_notif"
        phx-target={@myself}
        class="relative p-2 rounded-xl text-gray-500 hover:text-gray-800 hover:bg-gray-100 transition-colors"
        title="Notificaciones"
      >
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>
        <%= if @count > 0 do %>
          <span class="absolute -top-0.5 -right-0.5 min-w-[16px] h-[16px] flex items-center justify-center bg-red-500 text-white text-[9px] font-bold rounded-full px-1 leading-none">
            <%= if @count > 99, do: "99+", else: @count %>
          </span>
        <% end %>
      </button>

      <%= if @open do %>
        <div
          class="fixed inset-0 z-[90]"
          phx-click="cerrar_notif"
          phx-target={@myself}
        />
        <div class="absolute right-0 top-full mt-2 w-80 bg-white rounded-2xl shadow-2xl border border-gray-100 z-[100] overflow-hidden">
          <div class="flex items-center justify-between px-4 py-3 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <span class="text-sm font-bold text-gray-800">Notificaciones</span>
              <%= if @count > 0 do %>
                <span class="text-[10px] bg-red-100 text-red-600 font-semibold px-1.5 py-0.5 rounded-full"><%= @count %> nuevas</span>
              <% end %>
            </div>
            <%= if @count > 0 do %>
              <button phx-click="marcar_todas" phx-target={@myself}
                class="text-xs text-purple-600 hover:text-purple-700 font-medium transition-colors">
                Marcar todo leído
              </button>
            <% end %>
          </div>

          <div class="overflow-y-auto max-h-[360px] divide-y divide-gray-50">
            <%= if @notifications == [] do %>
              <div class="flex flex-col items-center justify-center py-12 text-gray-300">
                <svg class="w-12 h-12 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                <p class="text-xs font-medium">Sin notificaciones</p>
              </div>
            <% else %>
              <%= for notif <- @notifications do %>
                <button
                  phx-click="marcar_leida"
                  phx-value-id={notif.id}
                  phx-target={@myself}
                  class={"w-full text-left px-4 py-3 hover:bg-gray-50 transition-colors #{unless notif.leida, do: "bg-blue-50/40"}"}
                >
                  <div class="flex items-start gap-3">
                    <div class={"flex-shrink-0 w-7 h-7 rounded-full flex items-center justify-center mt-0.5 #{notif_bg(notif.tipo)}"}>
                      <%= Phoenix.HTML.raw(notif_svg(notif.tipo)) %>
                    </div>
                    <div class="flex-1 min-w-0 text-left">
                      <p class={"text-xs font-semibold truncate #{if notif.leida, do: "text-gray-400", else: "text-gray-800"}"}>
                        <%= notif.titulo %>
                      </p>
                      <%= if notif.mensaje && notif.mensaje != "" do %>
                        <p class="text-xs text-gray-400 mt-0.5 line-clamp-2 whitespace-normal"><%= notif.mensaje %></p>
                      <% end %>
                      <p class="text-[10px] text-gray-300 mt-1"><%= tiempo_relativo(notif.inserted_at) %></p>
                    </div>
                    <%= unless notif.leida do %>
                      <div class="flex-shrink-0 w-2 h-2 bg-blue-500 rounded-full mt-1.5"></div>
                    <% end %>
                  </div>
                </button>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp notif_bg("success"), do: "bg-green-100"
  defp notif_bg("warning"), do: "bg-amber-100"
  defp notif_bg("error"),   do: "bg-red-100"
  defp notif_bg(_),         do: "bg-blue-100"

  defp notif_svg("success") do
    ~s(<svg class="w-3.5 h-3.5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>)
  end
  defp notif_svg("warning") do
    ~s(<svg class="w-3.5 h-3.5 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/></svg>)
  end
  defp notif_svg("error") do
    ~s(<svg class="w-3.5 h-3.5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>)
  end
  defp notif_svg(_) do
    ~s(<svg class="w-3.5 h-3.5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>)
  end

  defp tiempo_relativo(dt) do
    now  = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)
    cond do
      diff < 60    -> "Ahora mismo"
      diff < 3600  -> "Hace #{div(diff, 60)} min"
      diff < 86400 -> "Hace #{div(diff, 3600)} h"
      diff < 604800 -> "Hace #{div(diff, 86400)} días"
      true -> Calendar.strftime(dt, "%d/%m %H:%M")
    end
  end
end
