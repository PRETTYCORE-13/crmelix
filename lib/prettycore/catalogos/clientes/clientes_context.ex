# lib/prettycore/catalogos/clientes/clientes_context.ex
defmodule Prettycore.Catalogos.Clientes.ClientesContext do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Catalogos.Clientes.{Cliente, Direccion, Contacto, TipoCliente}

  # ========== CLIENTES ==========
  def listar_clientes do
    Repo.all(Cliente)
  end

end
