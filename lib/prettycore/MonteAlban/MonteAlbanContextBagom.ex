defmodule Prettycore.MonteAlban.MonteAlbanContext do
  alias Prettycore.MonteAlban.MonteAlbanSchemaBagomSale
  alias Prettycore.PsqlRepo
  import Ecto.Query

  def count_listas do
    PsqlRepo.aggregate(MonteAlbanSchemaBagomSale, :count, :id)
  end

  def listar_listas(offset, limit) do
    MonteAlbanSchemaBagomSale
    |> order_by(desc: :id)
    |> offset(^offset)
    |> limit(^limit)
    |> PsqlRepo.all()
  end

 @doc """
  Inserta ventas en lote con atomicidad total.

  - Divide en fragmentos de 1_000 para evitar el límite de parámetros de PostgreSQL.
  - Usa Ecto.Multi + transacción: cualquier error en un chunk anula toda la operación.
  - Asigna un único timestamp `ahora` a todas las filas.

  Transacciones largas: si la lista supera los 100k registros, considera procesar
  por fuera para no bloquear la tabla por mucho tiempo.
  """
  def insertar_ventas_bagom(lista) when is_list(lista) do
    ahora = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    lista
    |> Enum.map(&preparar_fila(&1, ahora))
    |> Enum.chunk_every(1_000)
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {chunk, i}, multi ->
        Ecto.Multi.insert_all(multi, {:chunk, i}, MonteAlbanSchemaBagomSale, chunk)
       end)
    |> PsqlRepo.transaction()
  end

  defp preparar_fila(attrs, ahora) do
    %{
      fecha_prev:       parse_naive_dt(attrs["fecha_prev"]),
      fecha_liq:        parse_naive_dt(attrs["fecha_liq"]),
      udn:              attrs["udn"],
      folio:            attrs["folio"],
      id_cliente:       attrs["id_cliente"],
      sucursal:         attrs["sucursal"],
      id_producto:      attrs["id_producto"],
      nombre_producto:  attrs["nombre_producto"],
      ruta_prev:        attrs["ruta_prev"],
      ruta_rep:         attrs["ruta_rep"],
      cajas_prev:       attrs["cajas_prev"],
      cajas_liq:        attrs["cajas_liq"],
      monto_prev_bruto: attrs["monto_prev_bruto"],
      monto_liq_bruto:  attrs["monto_liq_bruto"],
      monto_prev_neta:  attrs["monto_prev_neta"],
      monto_liq_neta:   attrs["monto_liq_neta"],
      inserted_at:      ahora,
      updated_at:       ahora
    }
  end

  @doc """
   Convierte strings ISO 8601 a NaiveDateTime de forma segura.
   - nil             -> nil
   - string válido   -> %NaiveDateTime{}
   - string inválido -> nil (falla silenciosa)
   - cualquier otro  -> se devuelve tal cual (ya sea struct, número, etc.)
     Útil para castear parámetros en changesets de Ecto:
  cast(params, [:fecha], &parse_naive_dt/1)

  """

  defp parse_naive_dt(nil), do: nil
  defp parse_naive_dt(val) when is_binary(val) do
    case NaiveDateTime.from_iso8601(val) do
      {:ok, dt} -> dt
      _         -> nil
    end
  end
  defp parse_naive_dt(val), do: val
end
