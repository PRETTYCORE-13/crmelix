Mix.install([{:jason, "~> 1.4"}, {:req, "~> 0.4"}])

defmodule EnviadorVentas do
  @moduledoc """
  Genera registros de ventas y los envía al endpoint.
  """

  @udns ["MEX01", "MEX02", "MEX03", "GDL01", "MTY01", "QRO01"]
  @productos [
    {"PROD0042", "Agua 1L Ciel"},
    {"PROD0051", "Refresco Cola 2L"},
    {"PROD0067", "Pan Bimbo 400g"},
    {"PROD0072", "Leche Lala 1L"},
    {"PROD0089", "Cerveza XX 6-pack"},
    {"PROD0093", "Galletas María 200g"},
    {"PROD0102", "Jabón Zote 500g"},
    {"PROD0111", "Shampoo Head & Shoulders"}
  ]
  @rutas ["RUTA-NORTE", "RUTA-SUR", "RUTA-ESTE", "RUTA-OESTE", "RUTA-CENTRO"]

  @fecha_inicio Date.from_iso8601!("2026-05-01")
  @fecha_fin Date.from_iso8601!("2026-06-30")
  @dias_diff Date.diff(@fecha_fin, @fecha_inicio)

  @endpoint "http://localhost:4000/bagom/ventas"

  @doc """
  Envía los registros al endpoint.

  ## Parámetros
    - `cantidad` (opcional, default 200_000): número de registros.
    - `lote` (opcional, default nil): si se provee, envía en lotes de ese tamaño.
  """
  def enviar(cantidad \\ 200_000, lote \\ nil) do
    IO.puts("Generando #{cantidad} registros...")
    start = System.monotonic_time(:millisecond)

    registros =
      Enum.map(1..cantidad, fn folio ->
        generar_registro(folio)
      end)

    generacion_ms = System.monotonic_time(:millisecond) - start
    IO.puts("Generación completada en #{generacion_ms} ms")

    if lote do
      enviar_por_lotes(registros, lote)
    else
      enviar_todo(registros)
    end
  end

  defp enviar_todo(registros) do
    data = %{"registros" => registros}
    json = Jason.encode!(data)
    IO.puts("Tamaño del payload: #{round(byte_size(json) / 1024 / 1024)} MB")
    IO.puts("Enviando a #{@endpoint}...")

    case Req.post(@endpoint, json: data) do
      {:ok, %Req.Response{status: status, body: body}} ->
        IO.puts("✅ Respuesta HTTP #{status}")
        IO.inspect(body, label: "Body")
      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end
  end

  defp enviar_por_lotes(registros, lote) do
    total = length(registros)
    IO.puts("Enviando en lotes de #{lote} registros (#{ceil(total/lote)} peticiones)")

    registros
    |> Enum.chunk_every(lote)
    |> Enum.with_index(1)
    |> Enum.each(fn {chunk, i} ->
      data = %{"registros" => chunk}
      json = Jason.encode!(data)
      IO.puts("Lote #{i}: #{length(chunk)} regs, #{round(byte_size(json) / 1024)} KB")

      case Req.post(@endpoint, json: data) do
        {:ok, %Req.Response{status: status}} ->
          IO.puts("  ✅ Lote #{i} -> HTTP #{status}")
        {:error, reason} ->
          IO.puts("  ❌ Lote #{i} falló: #{inspect(reason)}")
      end

      # Pequeña pausa para no saturar el servidor
      :timer.sleep(100)
    end)

    IO.puts("✅ Todos los lotes enviados.")
  end

  defp generar_registro(folio) do
    dias_prev = :rand.uniform(@dias_diff + 1) - 1
    fecha_prev = Date.add(@fecha_inicio, dias_prev)
    max_dias_liq = min(7, Date.diff(@fecha_fin, fecha_prev))
    dias_liq = :rand.uniform(max_dias_liq + 1) - 1
    fecha_liq = Date.add(fecha_prev, dias_liq)

    {id_producto, nombre_producto} = Enum.random(@productos)

    cajas_prev = Float.round(:rand.uniform() * 100, 4)
    factor = 0.8 + :rand.uniform() * 0.4
    cajas_liq = Float.round(cajas_prev * factor, 4)

    precio_unitario = 10 + :rand.uniform() * 40
    monto_prev_bruto = Float.round(cajas_prev * precio_unitario, 4)
    monto_liq_bruto = Float.round(cajas_liq * precio_unitario, 4)

    monto_prev_neta = Float.round(monto_prev_bruto * 0.862, 4)
    monto_liq_neta = Float.round(monto_liq_bruto * 0.862, 4)

    %{
      "fecha_prev" => Date.to_iso8601(fecha_prev) <> "T00:00:00",
      "fecha_liq" => Date.to_iso8601(fecha_liq) <> "T00:00:00",
      "udn" => Enum.random(@udns),
      "folio" => folio,
      "id_cliente" => "CLI" <> String.pad_leading(Integer.to_string(:rand.uniform(99999)), 5, "0"),
      "sucursal" => :rand.uniform(10),
      "id_producto" => id_producto,
      "nombre_producto" => nombre_producto,
      "ruta_prev" => Enum.random(@rutas),
      "ruta_rep" => Enum.random(@rutas),
      "cajas_prev" => cajas_prev,
      "cajas_liq" => cajas_liq,
      "monto_prev_bruto" => monto_prev_bruto,
      "monto_liq_bruto" => monto_liq_bruto,
      "monto_prev_neta" => monto_prev_neta,
      "monto_liq_neta" => monto_liq_neta
    }
  end
end

# Ejecutar con 200,000 registros en lote de 10,000
EnviadorVentas.enviar(200_000, 10_000)
