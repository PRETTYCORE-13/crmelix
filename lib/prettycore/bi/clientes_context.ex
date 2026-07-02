defmodule Prettycore.BI.ClientesContext do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.BI.Cliente

  def count_clientes, do: Repo.aggregate(Cliente, :count)

  def count_clientes(filtros) do
    Cliente
    |> aplicar_filtros(filtros)
    |> Repo.aggregate(:count)
  end

  def listar_clientes(offset, limit, filtros \\ %{}) do
    Cliente
    |> aplicar_filtros(filtros)
    |> order_by([c], asc: c.id_cliente)
    |> offset(^offset)
    |> limit(^limit)
    |> Repo.all()
  end

  def obtener_cliente(id), do: Repo.get(Cliente, id)

  def buscar_cliente(id) do
    case obtener_cliente(id) do
      nil     -> {:error, :not_found}
      cliente -> {:ok, cliente}
    end
  end

  def crear_cliente(attrs) do
    %Cliente{}
    |> Cliente.changeset(attrs)
    |> Repo.insert()
  end

  def insertar_clientes(lista) when is_list(lista) do
    Repo.insert_all(Cliente, lista, on_conflict: :nothing)
  end

  defp aplicar_filtros(query, filtros) do
    Enum.reduce(filtros, query, fn
      {"id_cliente", id}, q      -> where(q, [c], c.id_cliente == ^id)
      {"udn", udn}, q            -> where(q, [c], c.udn == ^udn)
      {"nombre_comercial", n}, q -> where(q, [c], ilike(c.nombre_comercial, ^"%#{n}%"))
      {"preventa", p}, q         -> where(q, [c], c.preventa == ^p)
      {"reparto", r}, q          -> where(q, [c], c.reparto == ^r)
      _, q -> q
    end)
  end
end
