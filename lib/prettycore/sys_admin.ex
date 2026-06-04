defmodule Prettycore.SysAdmin do
  @moduledoc """
  Contexto para la configuración global del sistema (SYSADMIN).
  Singleton: siempre usa id=1.
  """

  alias Prettycore.PsqlRepo
  alias Prettycore.SysAdmin.Config

  @singleton_id 1
  @cache_key :sysadmin_config_cache

  def get_config do
    case :persistent_term.get(@cache_key, nil) do
      nil -> load_and_cache()
      config -> config
    end
  end

  def invalidate_cache do
    :persistent_term.erase(@cache_key)
  rescue
    _ -> :ok
  end

  def save_config(attrs) do
    result =
      case PsqlRepo.get(Config, @singleton_id) do
        nil ->
          %Config{id: @singleton_id}
          |> Config.changeset(attrs)
          |> PsqlRepo.insert()
        config ->
          config
          |> Config.changeset(attrs)
          |> PsqlRepo.update()
      end
    invalidate_cache()
    result
  end

  defp load_and_cache do
    config =
      case PsqlRepo.get(Config, @singleton_id) do
        nil -> %Config{id: @singleton_id, foto: ""}
        c -> c
      end
    :persistent_term.put(@cache_key, config)
    config
  end
end
