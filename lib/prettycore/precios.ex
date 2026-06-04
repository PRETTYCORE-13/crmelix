defmodule Prettycore.Precios do
  @moduledoc """
  Manejo de precios de productos: sincronización desde API externa y lectura desde DB.
  """

  alias Prettycore.Precios.Precio
  alias Prettycore.PsqlRepo, as: Repo
  import Ecto.Query

  # ── DB → Assigns ──────────────────────────────────────────────────────────

  @doc """
  Retorna %{codigo_producto => precio_float} leyendo desde la base de datos.
  No llama a la API externa.
  """
  def get_precios_map(cliente_codigo, dir_codigo)
      when is_binary(cliente_codigo) and cliente_codigo != "" do
    dir = if is_binary(dir_codigo) and dir_codigo != "", do: dir_codigo, else: "1"

    from(p in Precio,
      where: p.cliente_codigo == ^cliente_codigo and p.dir_codigo == ^dir,
      select: {p.producto_codigo, p.precio}
    )
    |> Repo.all()
    |> Map.new()
  end

  def get_precios_map(_, _), do: %{}

  # ── Privado ───────────────────────────────────────────────────────────────

  defp save_precios(lista, cliente, dir) do
    require Logger
    Logger.debug("save_precios: #{length(lista)} registros para cliente=#{cliente} dir=#{dir}")
    Logger.debug("save_precios primer item: #{inspect(List.first(lista))}")

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    entries =
      lista
      |> Enum.reject(fn item ->
        codigo = to_string(item["PRODUC_CODIGO_K"] || "")
        codigo == ""
      end)
      |> Enum.uniq_by(fn item -> to_string(item["PRODUC_CODIGO_K"]) end)
      |> Enum.map(fn item ->
        %{
          id: Ecto.UUID.generate(),
          producto_codigo: to_string(item["PRODUC_CODIGO_K"]),
          precio: item["VTAPRE_PRECIO"] || 0.0,
          cliente_codigo: cliente,
          dir_codigo: dir,
          lista_precio: item["VTAPRL_CODIGO_K"],
          unidad: String.trim(to_string(item["PROUND_CODIGO_K"] || "")),
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(
        Precio,
        entries,
        on_conflict: {:replace, [:precio, :lista_precio, :unidad, :updated_at]},
        conflict_target: [:cliente_codigo, :dir_codigo, :producto_codigo]
      )

    {:ok, count}
  end
end
