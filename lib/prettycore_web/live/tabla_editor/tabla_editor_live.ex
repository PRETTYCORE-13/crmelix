defmodule PrettycoreWeb.TablaEditorLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Meta
  alias Prettycore.PsqlRepo
  alias PrettycoreWeb.AdminNav

  @reservados ~w(id inserted_at updated_at)

  @impl true
  def mount(_params, _session, socket) do
    tablas = Meta.listar_esquema() |> Enum.filter(& &1.tabla_creada)
    {:ok, socket
      |> assign(:current_page,  "editor")
      |> assign(:sidebar_open,  false)
      |> assign(:tablas,        tablas)
      |> assign(:tabla_sel,     nil)
      |> assign(:filas,         [])
      |> assign(:cols_def,      [])
      |> assign(:form_abierto,  false)
      |> assign(:form_attrs,    %{})
      |> assign(:error,         nil)
    }
  end

  @impl true
  def handle_event("change_page", params, socket),
    do: AdminNav.handle_nav(params["id"], socket, "editor")

  def handle_event("seleccionar_tabla", %{"id" => id}, socket) do
    tabla    = Meta.obtener_contexto!(id)
    cols_def = tabla.columnas |> Enum.sort_by(& &1.orden) |> Enum.reject(&(&1.nombre in @reservados))
    filas    = cargar_filas(tabla.tabla_db)
    form_attrs = cols_def |> Enum.map(&{&1.nombre, ""}) |> Map.new()
    {:noreply, assign(socket,
      tabla_sel:   tabla,
      cols_def:    cols_def,
      filas:       filas,
      form_abierto: false,
      form_attrs:  form_attrs,
      error:       nil
    )}
  end

  def handle_event("abrir_form", _, socket),
    do: {:noreply, assign(socket, form_abierto: true, error: nil)}

  def handle_event("cerrar_form", _, socket),
    do: {:noreply, assign(socket, form_abierto: false, error: nil)}

  def handle_event("form_change", %{"fila" => attrs}, socket),
    do: {:noreply, assign(socket, form_attrs: attrs)}

  def handle_event("insertar", %{"fila" => attrs}, socket) do
    %{tabla_sel: tabla, cols_def: cols_def} = socket.assigns
    campos       = Enum.map(cols_def, & &1.nombre)
    valores      = Enum.map(campos, &Map.get(attrs, &1))
    placeholders = 1..length(campos) |> Enum.map(&"$#{&1}") |> Enum.join(", ")
    sql = "INSERT INTO #{tabla.tabla_db} (#{Enum.join(campos, ", ")}) VALUES (#{placeholders})"

    case Ecto.Adapters.SQL.query(PsqlRepo, sql, valores) do
      {:ok, _} ->
        filas      = cargar_filas(tabla.tabla_db)
        form_attrs = cols_def |> Enum.map(&{&1.nombre, ""}) |> Map.new()
        {:noreply, assign(socket, filas: filas, form_abierto: false, form_attrs: form_attrs, error: nil)}
      {:error, %{postgres: %{message: msg}}} ->
        {:noreply, assign(socket, error: msg)}
    end
  end

  def handle_event("borrar_fila", %{"id" => row_id}, socket) do
    %{tabla_sel: tabla} = socket.assigns
    sql = "DELETE FROM #{tabla.tabla_db} WHERE id = $1"
    case Ecto.Adapters.SQL.query(PsqlRepo, sql, [row_id]) do
      {:ok, _} ->
        {:noreply, assign(socket, filas: cargar_filas(tabla.tabla_db), error: nil)}
      {:error, %{postgres: %{message: msg}}} ->
        {:noreply, assign(socket, error: msg)}
    end
  end

  def handle_event("recargar", _, socket) do
    case socket.assigns.tabla_sel do
      nil   -> {:noreply, socket}
      tabla -> {:noreply, assign(socket, filas: cargar_filas(tabla.tabla_db))}
    end
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp cargar_filas(tabla_db) do
    sql = "SELECT * FROM #{tabla_db} ORDER BY inserted_at DESC LIMIT 200"
    case Ecto.Adapters.SQL.query(PsqlRepo, sql, []) do
      {:ok, res} ->
        cols = Enum.map(res.columns, &String.to_atom/1)
        Enum.map(res.rows, fn row ->
          row |> Enum.map(&encode_value/1) |> then(&Enum.zip(cols, &1)) |> Map.new()
        end)
      _ -> []
    end
  end

  defp encode_value(v) when is_binary(v) do
    if String.valid?(v) do
      v
    else
      case byte_size(v) do
        16 -> Ecto.UUID.load!(v)
        _  -> Base.encode64(v)
      end
    end
  end
  defp encode_value(%NaiveDateTime{} = dt) do
    dt |> NaiveDateTime.to_iso8601() |> String.replace("T", " ") |> String.slice(0, 19)
  end
  defp encode_value(%DateTime{} = dt), do: dt |> DateTime.to_iso8601() |> String.slice(0, 19)
  defp encode_value(%Date{} = d),      do: Date.to_iso8601(d)
  defp encode_value(nil),              do: nil
  defp encode_value(v),                do: v

  def tipo_input("text"),     do: "textarea"
  def tipo_input("integer"),  do: "number"
  def tipo_input("float"),    do: "number"
  def tipo_input("date"),     do: "date"
  def tipo_input("datetime"), do: "datetime-local"
  def tipo_input(_),          do: "text"
end
