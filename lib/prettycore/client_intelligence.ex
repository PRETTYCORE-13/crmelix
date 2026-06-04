defmodule Prettycore.ClientIntelligence do
  @moduledoc """
  Client Intelligence: registra eventos de interacción con clientes,
  computa métricas de actividad y analiza estadísticas de ventas.
  """
  import Ecto.Query
  require Logger

  alias Prettycore.PsqlRepo
  alias Prettycore.ClientIntelligence.CiEvent
  alias Prettycore.ClientIntelligence.CiScore
  alias Prettycore.ClientIntelligence.CiClientStats

  # ── Tracking ─────────────────────────────────────────────────

  @doc """
  Registra un evento para un cliente. Lanza de forma asíncrona para
  no bloquear el request del usuario.

  event_type: "viewed" | "edited" | "exported"
  """
  def track_event(client_code, user_id, event_type, metadata \\ %{}) do
    Task.start(fn ->
      now = DateTime.truncate(DateTime.utc_now(), :second)

      result =
        %CiEvent{}
        |> CiEvent.changeset(%{
          client_code: client_code,
          user_id: user_id,
          event_type: event_type,
          metadata: metadata,
          inserted_at: now
        })
        |> PsqlRepo.insert()

      case result do
        {:ok, _} -> recompute_score(client_code)
        {:error, changeset} -> Logger.warning("CI track_event error: #{inspect(changeset.errors)}")
      end
    end)

    :ok
  end

  # ── Scores ────────────────────────────────────────────────────

  @doc """
  Devuelve el score de un cliente (puede ser nil si nunca tuvo actividad).
  """
  def get_score(client_code) do
    PsqlRepo.get_by(CiScore, client_code: client_code)
  end

  @doc """
  Lista los N clientes más activos en los últimos 30 días.
  """
  def list_most_active(limit \\ 10) do
    CiScore
    |> where([s], s.activity_score > 0)
    |> order_by([s], desc: s.activity_score)
    |> limit(^limit)
    |> PsqlRepo.all()
  end

  @doc """
  Lista la actividad reciente (últimos N eventos), con info de usuario.
  """
  def list_recent_events(limit \\ 30) do
    CiEvent
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> PsqlRepo.all()
  end

  @doc """
  Conteo desglosado por tipo de evento: vistas, edits, creados, exportados, filtros.
  Retorna mapa %{tipo => %{today: n, week: n}}.
  """
  def event_type_breakdown do
    now = DateTime.utc_now()
    today_start = DateTime.truncate(%{now | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}, :second)
    week_start  = DateTime.add(today_start, -6 * 86_400, :second)

    for type <- ~w(viewed edited created exported filtered), into: %{} do
      today =
        CiEvent
        |> where([e], e.event_type == ^type and e.inserted_at >= ^today_start)
        |> PsqlRepo.aggregate(:count, :id)

      week =
        CiEvent
        |> where([e], e.event_type == ^type and e.inserted_at >= ^week_start)
        |> PsqlRepo.aggregate(:count, :id)

      {type, %{today: today, week: week}}
    end
  end

  @doc """
  Lista los últimos N eventos con todos los detalles (usuario, metadata, timestamp exacto).
  """
  def list_detailed_events(limit \\ 100) do
    CiEvent
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> PsqlRepo.all()
  end

  @doc """
  Totales globales: eventos hoy, esta semana, usuarios activos distintos.
  """
  def global_stats do
    now = DateTime.utc_now()
    today_start = DateTime.truncate(%{now | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}, :second)
    week_start  = DateTime.add(today_start, -6 * 86_400, :second)

    total_events = PsqlRepo.aggregate(CiEvent, :count, :id)

    events_today =
      CiEvent
      |> where([e], e.inserted_at >= ^today_start)
      |> PsqlRepo.aggregate(:count, :id)

    events_week =
      CiEvent
      |> where([e], e.inserted_at >= ^week_start)
      |> PsqlRepo.aggregate(:count, :id)

    unique_clients =
      CiEvent
      |> where([e], e.inserted_at >= ^week_start)
      |> select([e], count(e.client_code, :distinct))
      |> PsqlRepo.one()

    %{
      total_events: total_events,
      events_today: events_today,
      events_week: events_week,
      unique_clients_week: unique_clients
    }
  end

  # ── Cómputo de score ──────────────────────────────────────────

  defp recompute_score(client_code) do
    now    = DateTime.truncate(DateTime.utc_now(), :second)
    cutoff = DateTime.add(now, -30 * 86_400, :second)

    events_30d =
      CiEvent
      |> where([e], e.client_code == ^client_code and e.inserted_at >= ^cutoff)
      |> PsqlRepo.all()

    view_count = Enum.count(events_30d, &(&1.event_type == "viewed"))
    edit_count = Enum.count(events_30d, &(&1.event_type == "edited"))

    activity_score = compute_activity_score(view_count, edit_count)

    last_viewed =
      events_30d
      |> Enum.filter(&(&1.event_type == "viewed"))
      |> Enum.max_by(& &1.inserted_at, DateTime, fn -> nil end)
      |> then(&if &1, do: &1.inserted_at)

    last_edited =
      events_30d
      |> Enum.filter(&(&1.event_type == "edited"))
      |> Enum.max_by(& &1.inserted_at, DateTime, fn -> nil end)
      |> then(&if &1, do: &1.inserted_at)

    attrs = %{
      client_code: client_code,
      activity_score: activity_score,
      view_count_30d: view_count,
      edit_count_30d: edit_count,
      last_viewed_at: last_viewed,
      last_edited_at: last_edited,
      computed_at: now
    }

    case PsqlRepo.get_by(CiScore, client_code: client_code) do
      nil ->
        %CiScore{} |> CiScore.changeset(attrs) |> PsqlRepo.insert()

      existing ->
        existing |> CiScore.changeset(attrs) |> PsqlRepo.update()
    end
  end

  # Fórmula: edits valen 3x más que views, cap en 100
  defp compute_activity_score(views, edits) do
    raw = views * 1 + edits * 3
    min(raw, 100)
  end

  # ── Analytics: estadísticas de ventas ─────────────────────────

  @doc """
  Lista todos los stats de clientes guardados en DB, ordenados por venta anual DESC.
  Retorna también cuándo fue el último fetch.
  """
  def list_client_stats do
    CiClientStats
    |> order_by([s], desc: s.total_venta_anual)
    |> PsqlRepo.all()
  end

  @doc """
  Fecha del último fetch (nil si nunca se ha actualizado).
  """
  def last_stats_fetched_at do
    CiClientStats
    |> select([s], max(s.fetched_at))
    |> PsqlRepo.one()
  end

  def fetch_and_store_all_stats(_token \\ nil, _page \\ 0, _only_missing \\ false) do
    {:ok, %{processed: 0, total_clients: 0, has_more: false}}
  end


  @doc "Cuenta cuántos clientes tienen stats guardadas vs total en API"
  def stats_progress do
    saved = PsqlRepo.aggregate(CiClientStats, :count, :id)
    %{saved: saved}
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(v) when is_float(v), do: v
  defp parse_float(v) when is_integer(v), do: v * 1.0
  defp parse_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  @doc """
  Genera un reporte de análisis basado en las stats guardadas.
  Retorna una lista de insights con nivel de importancia.
  """
  def generate_analysis(stats) when is_list(stats) do
    total = length(stats)

    if total == 0 do
      [%{level: :info, text: "Sin datos disponibles. Actualiza las estadísticas primero."}]
    else
      insights = []

      # Venta total
      venta_total = Enum.sum(Enum.map(stats, & &1.total_venta_anual))

      # Top 3 por venta
      top3 = stats |> Enum.filter(&(&1.total_venta_anual > 0)) |> Enum.take(3)
      top3_names = Enum.map_join(top3, ", ", &"#{&1.client_name || &1.client_code}")
      top3_pct =
        if venta_total > 0 do
          top3_venta = Enum.sum(Enum.map(top3, & &1.total_venta_anual))
          round(top3_venta / venta_total * 100)
        else
          0
        end

      insights =
        if top3 != [],
          do: [%{level: :success, text: "Top 3 clientes (#{top3_names}) concentran el #{top3_pct}% de la venta anual."} | insights],
          else: insights

      # Sin venta
      sin_venta = Enum.count(stats, &(&1.total_venta_anual == 0.0))
      insights =
        if sin_venta > 0,
          do: [%{level: :warning, text: "#{sin_venta} clientes sin venta registrada en el año — revisar activación."} | insights],
          else: insights

      # Cartera vencida
      con_cartera = Enum.filter(stats, &(&1.cartera_vencida > 0))
      cartera_total = Enum.sum(Enum.map(con_cartera, & &1.cartera_vencida))
      insights =
        if length(con_cartera) > 0 do
          top_riesgo = con_cartera |> Enum.sort_by(& &1.cartera_vencida, :desc) |> hd()
          [%{level: :danger,
             text: "#{length(con_cartera)} clientes con cartera vencida (total $#{format_money(cartera_total)}). Mayor riesgo: #{top_riesgo.client_name || top_riesgo.client_code} ($#{format_money(top_riesgo.cartera_vencida)})."}
           | insights]
        else
          insights
        end

      # Clientes clasificación B o C (oportunidad de subir)
      oportunidad = Enum.filter(stats, &(&1.clasificacion in ["B", "C"]))
      insights =
        if length(oportunidad) > 0,
          do: [%{level: :info, text: "#{length(oportunidad)} clientes en clasificación B/C con potencial de crecimiento hacia clasificación A."} | insights],
          else: insights

      # Clientes con enfriadores sin autoventa (oportunidad canal)
      con_enfriador = Enum.filter(stats, &(&1.enfriadores > 0))
      insights =
        if length(con_enfriador) > 0,
          do: [%{level: :info, text: "#{length(con_enfriador)} clientes tienen #{Enum.sum(Enum.map(con_enfriador, & &1.enfriadores))} enfriadores instalados."} | insights],
          else: insights

      # Resumen global
      insights = [
        %{level: :summary, text: "Cartera de #{total} clientes analizados. Venta anual total: $#{format_money(venta_total)}."}
        | insights
      ]

      Enum.reverse(insights)
    end
  end

  defp format_money(amount) when is_float(amount) or is_integer(amount) do
    amount
    |> round()
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
  defp format_money(_), do: "0"
end
