# lib/prettycore/catalogos/clientes/clientes_context.ex
defmodule Prettycore.Catalogos.Clientes.ClientesContext do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Catalogos.Clientes.{Cliente, Direccion, Contacto, TipoCliente}

  # ========== CLIENTES ==========
  def listar_clientes, do: Repo.all(Cliente)

  def listar_clientes(offset, limit) do
    Cliente |> offset(^offset) |> limit(^limit) |> Repo.all()
  end

  def count_clientes, do: Repo.aggregate(Cliente, :count)

  def obtener_cliente(id) do
    Repo.get(Cliente, id)
  end

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

  def actualizar_cliente(%Cliente{} = cliente, attrs) do
    cliente
    |> Cliente.changeset(attrs)
    |> Repo.update()
  end

end
