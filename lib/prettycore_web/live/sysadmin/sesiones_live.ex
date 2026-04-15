defmodule PrettycoreWeb.SysAdmin.SesionesLive do
  use PrettycoreWeb, :live_view

  import PrettycoreWeb.SysAdminLayout

  alias Prettycore.Auth

  @active_threshold_minutes 30
  @refresh_interval_ms 30_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@refresh_interval_ms, self(), :refresh)

    sessions = load_sessions()

    {:ok,
     socket
     |> assign(:current_page, "sesiones")
     |> assign(:sessions, sessions)
     |> assign(:stats, compute_stats(sessions))
     |> assign(:filter, "all")}
  end

  @impl true
  def handle_info(:refresh, socket) do
    sessions = load_sessions()
    {:noreply, socket |> assign(:sessions, sessions) |> assign(:stats, compute_stats(sessions))}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :filter, filter)}
  end

  @impl true
  def handle_event("force_close", %{"id" => id}, socket) do
    Auth.force_close_session(id)
    sessions = load_sessions()
    {:noreply, socket |> assign(:sessions, sessions) |> assign(:stats, compute_stats(sessions))}
  end

  @impl true
  def handle_event("force_close_all", _, socket) do
    Auth.force_close_all_open_sessions()
    sessions = load_sessions()
    {:noreply, socket |> assign(:sessions, sessions) |> assign(:stats, compute_stats(sessions))}
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp load_sessions, do: Auth.list_user_sessions()

  defp compute_stats(sessions) do
    now = DateTime.utc_now()
    # inserted_at viene como NaiveDateTime de Ecto timestamps()
    today_start = NaiveDateTime.new!(Date.utc_today(), ~T[00:00:00])

    active = Enum.count(sessions, &(session_status(&1, now) == :active))
    today  = Enum.count(sessions, fn s ->
      not is_nil(s.inserted_at) and
      NaiveDateTime.compare(s.inserted_at, today_start) != :lt
    end)
    unique = sessions |> Enum.map(& &1.username) |> Enum.uniq() |> length()

    %{active: active, today: today, unique_users: unique, total: length(sessions)}
  end

  defp session_status(%{logged_out_at: lo}, _now) when not is_nil(lo), do: :closed
  defp session_status(%{last_seen_at: nil}, _now), do: :inactive
  defp session_status(%{last_seen_at: ls}, now) do
    threshold = DateTime.add(now, -@active_threshold_minutes * 60, :second)
    if DateTime.compare(ls, threshold) == :gt, do: :active, else: :inactive
  end

  defp filtered_sessions(sessions, "active") do
    now = DateTime.utc_now()
    Enum.filter(sessions, &(session_status(&1, now) == :active))
  end
  defp filtered_sessions(sessions, "inactive") do
    now = DateTime.utc_now()
    Enum.filter(sessions, &(session_status(&1, now) == :inactive))
  end
  defp filtered_sessions(sessions, "closed") do
    now = DateTime.utc_now()
    Enum.filter(sessions, &(session_status(&1, now) == :closed))
  end
  defp filtered_sessions(sessions, _all), do: sessions

  defp relative_time(nil), do: "—"
  defp relative_time(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)
    cond do
      diff < 60         -> "hace #{diff}s"
      diff < 3600       -> "hace #{div(diff, 60)}min"
      diff < 86400      -> "hace #{div(diff, 3600)}h"
      true              -> "hace #{div(diff, 86400)}d"
    end
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt) do
    # inserted_at es NaiveDateTime; last_seen_at/logged_out_at son DateTime
    utc_dt = case dt do
      %NaiveDateTime{} -> DateTime.from_naive!(dt, "Etc/UTC")
      _ -> dt
    end
    utc_dt
    |> DateTime.shift_zone!("America/Mexico_City")
    |> Calendar.strftime("%d/%m/%y %H:%M")
  rescue
    _ -> Calendar.strftime(dt, "%d/%m/%y %H:%M")
  end

  defp device_icon("Mobile"),  do: "📱"
  defp device_icon("Tablet"),  do: "📟"
  defp device_icon(_),         do: "💻"

  defp status_badge(:active),   do: {"Activa",   "bg-emerald-100 text-emerald-700 border border-emerald-200"}
  defp status_badge(:inactive), do: {"Inactiva",  "bg-amber-100 text-amber-700 border border-amber-200"}
  defp status_badge(:closed),   do: {"Cerrada",   "bg-gray-100 text-gray-500 border border-gray-200"}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :now, DateTime.utc_now())
    assigns = assign(assigns, :visible_sessions, filtered_sessions(assigns.sessions, assigns.filter))

    ~H"""
    <.sidebar current_page={@current_page} current_user_name={@current_user_name}>
      <div class="p-8 max-w-6xl">

        <!-- Header -->
        <div class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Sesiones activas</h1>
            <p class="text-sm text-gray-500 mt-1">
              Monitoreo de accesos. Se actualiza cada 30 segundos.
            </p>
          </div>
          <div class="flex items-center gap-2 text-xs text-gray-400">
            <span class="inline-block w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            En vivo
          </div>
        </div>

        <!-- Stats -->
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
          <div class="bg-white rounded-2xl border border-gray-200 p-5 shadow-sm">
            <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide">Activas ahora</p>
            <p class="text-3xl font-bold text-emerald-600 mt-1"><%= @stats.active %></p>
          </div>
          <div class="bg-white rounded-2xl border border-gray-200 p-5 shadow-sm">
            <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide">Logins hoy</p>
            <p class="text-3xl font-bold text-blue-600 mt-1"><%= @stats.today %></p>
          </div>
          <div class="bg-white rounded-2xl border border-gray-200 p-5 shadow-sm">
            <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide">Usuarios distintos</p>
            <p class="text-3xl font-bold text-violet-600 mt-1"><%= @stats.unique_users %></p>
          </div>
          <div class="bg-white rounded-2xl border border-gray-200 p-5 shadow-sm">
            <p class="text-xs font-semibold text-gray-400 uppercase tracking-wide">Total histórico</p>
            <p class="text-3xl font-bold text-gray-700 mt-1"><%= @stats.total %></p>
          </div>
        </div>

        <!-- Filtros + acción global -->
        <div class="flex gap-2 mb-4 flex-wrap items-center">
          <%= for {label, value} <- [{"Todas", "all"}, {"Activas", "active"}, {"Inactivas", "inactive"}, {"Cerradas", "closed"}] do %>
            <button
              type="button"
              phx-click="set_filter"
              phx-value-filter={value}
              class={
                "px-4 py-1.5 text-xs font-semibold rounded-full border transition-colors " <>
                if @filter == value,
                  do: "bg-gray-900 text-white border-gray-900",
                  else: "bg-white text-gray-600 border-gray-200 hover:border-gray-400"
              }
            >
              <%= label %>
            </button>
          <% end %>
          <span class="text-xs text-gray-400 self-center">
            <%= length(@visible_sessions) %> sesión<%= if length(@visible_sessions) != 1, do: "es" %>
          </span>
          <%= if @stats.active > 0 do %>
            <button
              type="button"
              phx-click="force_close_all"
              data-confirm={"¿Cerrar TODAS las #{@stats.active} sesiones abiertas? Los usuarios serán desconectados en su próximo request."}
              class="ml-auto px-4 py-1.5 text-xs font-semibold rounded-full border border-red-200 text-red-600 bg-white hover:bg-red-50 transition-colors"
            >
              Cerrar todas las activas
            </button>
          <% end %>
        </div>

        <!-- Vista móvil: cards expandibles -->
        <div class="sm:hidden bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <%= if @visible_sessions == [] do %>
            <div class="py-16 text-center text-gray-400 text-sm">No hay sesiones para mostrar.</div>
          <% else %>
            <%= for session <- @visible_sessions do %>
              <% status = session_status(session, @now) %>
              <% {label, badge_class} = status_badge(status) %>
              <details class="border-b border-gray-100 last:border-0 group">
                <summary class="flex items-center gap-3 px-4 py-3 cursor-pointer list-none select-none">
                  <!-- Avatar -->
                  <div class="w-9 h-9 rounded-full bg-gray-900 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">
                    <%= (String.first(session.username || "?") || "?") |> String.upcase() %>
                  </div>
                  <!-- Nombre + email -->
                  <div class="flex-1 min-w-0">
                    <p class="font-semibold text-gray-900 text-sm truncate"><%= session.username %></p>
                    <p class="text-xs text-gray-400 truncate"><%= session.email %></p>
                  </div>
                  <!-- Estado + chevron -->
                  <div class="flex items-center gap-2 flex-shrink-0">
                    <span class={"inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold #{badge_class}"}>
                      <span class={"w-1.5 h-1.5 rounded-full " <> case status do
                        :active   -> "bg-emerald-500"
                        :inactive -> "bg-amber-500"
                        :closed   -> "bg-gray-400"
                      end}></span>
                      <%= label %>
                    </span>
                    <svg class="w-4 h-4 text-gray-400 transition-transform group-open:rotate-180" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                      <polyline points="6 9 12 15 18 9" />
                    </svg>
                  </div>
                </summary>
                <!-- Detalles expandidos -->
                <div class="px-4 pb-4 pt-1 grid grid-cols-2 gap-x-4 gap-y-2 text-xs bg-gray-50">
                  <div>
                    <p class="text-gray-400 uppercase font-semibold tracking-wide text-[10px]">IP</p>
                    <code class="text-gray-700 font-mono"><%= session.ip_address || "—" %></code>
                  </div>
                  <div>
                    <p class="text-gray-400 uppercase font-semibold tracking-wide text-[10px]">Dispositivo</p>
                    <p class="text-gray-700"><%= device_icon(session.device_type) %> <%= session.device_type || "—" %></p>
                    <p class="text-gray-400"><%= session.os %></p>
                  </div>
                  <div>
                    <p class="text-gray-400 uppercase font-semibold tracking-wide text-[10px]">Navegador</p>
                    <p class="text-gray-700"><%= session.browser || "—" %></p>
                  </div>
                  <div>
                    <p class="text-gray-400 uppercase font-semibold tracking-wide text-[10px]">Inicio</p>
                    <p class="text-gray-700"><%= format_datetime(session.inserted_at) %></p>
                  </div>
                  <div class="col-span-2 flex items-center justify-between">
                    <div>
                      <p class="text-gray-400 uppercase font-semibold tracking-wide text-[10px]">Última actividad</p>
                      <p class="text-gray-700"><%= relative_time(session.last_seen_at) %></p>
                    </div>
                    <%= if is_nil(session.logged_out_at) do %>
                      <button
                        type="button"
                        phx-click="force_close"
                        phx-value-id={session.id}
                        data-confirm={"¿Cerrar la sesión de #{session.username}?"}
                        class="px-3 py-1.5 text-xs font-semibold text-red-600 border border-red-200 rounded-lg bg-white hover:bg-red-50"
                      >
                        Cerrar sesión
                      </button>
                    <% end %>
                  </div>
                </div>
              </details>
            <% end %>
          <% end %>
        </div>

        <!-- Vista desktop: tabla completa -->
        <div class="hidden sm:block bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <%= if @visible_sessions == [] do %>
            <div class="py-16 text-center text-gray-400 text-sm">No hay sesiones para mostrar.</div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-100 bg-gray-50">
                    <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">Usuario</th>
                    <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">IP</th>
                    <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">Dispositivo</th>
                    <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">Navegador</th>
                    <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">Inicio</th>
                    <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">Última actividad</th>
                    <th class="px-5 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">Estado</th>
                    <th class="px-5 py-3"></th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-50">
                  <%= for session <- @visible_sessions do %>
                    <% status = session_status(session, @now) %>
                    <% {label, badge_class} = status_badge(status) %>
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="px-5 py-4">
                        <div class="flex items-center gap-3">
                          <div class="w-8 h-8 rounded-full bg-gray-900 text-white flex items-center justify-center text-xs font-bold flex-shrink-0">
                            <%= (String.first(session.username || "?") || "?") |> String.upcase() %>
                          </div>
                          <div>
                            <p class="font-semibold text-gray-900"><%= session.username %></p>
                            <p class="text-xs text-gray-400"><%= session.email %></p>
                          </div>
                        </div>
                      </td>
                      <td class="px-5 py-4">
                        <code class="text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded font-mono">
                          <%= session.ip_address || "—" %>
                        </code>
                      </td>
                      <td class="px-5 py-4">
                        <span class="text-base"><%= device_icon(session.device_type) %></span>
                        <span class="text-gray-700 ml-1"><%= session.device_type || "—" %></span>
                        <br/>
                        <span class="text-xs text-gray-400"><%= session.os %></span>
                      </td>
                      <td class="px-5 py-4 text-gray-700"><%= session.browser || "—" %></td>
                      <td class="px-5 py-4 text-gray-600 text-xs whitespace-nowrap"><%= format_datetime(session.inserted_at) %></td>
                      <td class="px-5 py-4 text-gray-600 text-xs whitespace-nowrap"><%= relative_time(session.last_seen_at) %></td>
                      <td class="px-5 py-4">
                        <span class={"inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold #{badge_class}"}>
                          <span class={"w-1.5 h-1.5 rounded-full " <> case status do
                            :active   -> "bg-emerald-500"
                            :inactive -> "bg-amber-500"
                            :closed   -> "bg-gray-400"
                          end}></span>
                          <%= label %>
                        </span>
                      </td>
                      <td class="px-5 py-4 text-right">
                        <%= if is_nil(session.logged_out_at) do %>
                          <button
                            type="button"
                            phx-click="force_close"
                            phx-value-id={session.id}
                            data-confirm={"¿Cerrar la sesión de #{session.username}? Será desconectado en su próximo request."}
                            class="text-xs font-semibold text-red-500 hover:text-red-700 hover:underline transition-colors"
                          >
                            Cerrar
                          </button>
                        <% else %>
                          <span class="text-xs text-gray-300">—</span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>

      </div>
    </.sidebar>
    """
  end
end
