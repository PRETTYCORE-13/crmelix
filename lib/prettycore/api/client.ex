defmodule Prettycore.Api.Client do
  @moduledoc """
  Cliente HTTP centralizado para consumir la API REST EN_RESTHELPER.

  Base URL: https://s2.ecore.ninja:1522/SP/EN_RESTHELPER/

  Todas las tablas soportadas:
  - CTE_CLIENTE, CTE_DIRECCION
  - SYS_USUARIO, XEN_SYS_USUARIO
  - XEN_WOKORDERENC, XEN_WOKORDERTIPO, XEN_WOKORDERDET
  - CTE_TIPO, CTE_CANAL, CTE_SUBCANAL, CTE_CADENA, CTE_PAQUETESERV, CTE_REGIMEN
  - SYS_TRANSAC, CFG_MONEDA, VTA_RUTA
  - MAP_ESTADO, MAP_MUNICIPIO, MAP_LOCALIDAD
  - CFG_USOCFDISAT, CFG_FORMAPAGO_SAT, CFG_METODOPAGO, CFG_REGIMENFISCAL_SAT
  """
  require Logger

  @timeout 15_000

  # TTL del caché de config en ms (5 minutos)
  @config_cache_ttl 300_000

  @doc "URL base de la API — cacheada 5 min para evitar N queries DB en operaciones bulk"
  def base_url do
    case :persistent_term.get(:cache_api_base_url, nil) do
      {url, ts} when is_binary(url) ->
        if System.monotonic_time(:millisecond) - ts < @config_cache_ttl do
          url
        else
          fetch_and_cache_base_url()
        end
      _ ->
        fetch_and_cache_base_url()
    end
  end

  @doc "Token de servicio — cacheado 5 min"
  def service_token do
    case :persistent_term.get(:cache_api_service_token, nil) do
      {token, ts} when is_binary(token) ->
        if System.monotonic_time(:millisecond) - ts < @config_cache_ttl do
          token
        else
          fetch_and_cache_service_token()
        end
      _ ->
        fetch_and_cache_service_token()
    end
  end

  @doc "Invalida el caché de config (llamar tras guardar system_config)"
  def invalidate_config_cache do
    :persistent_term.erase(:cache_api_base_url)
    :persistent_term.erase(:cache_api_service_token)
  end

  defp fetch_and_cache_base_url do
    url = case Prettycore.SysAdmin.get_config() do
      %{url: url} when is_binary(url) and url != "" ->
        String.trim_trailing(url, "/") <> "/SP/EN_RESTHELPER"
      _ -> "https://s2.ecore.ninja:1522/SP/EN_RESTHELPER"
    end
    :persistent_term.put(:cache_api_base_url, {url, System.monotonic_time(:millisecond)})
    url
  end

  defp fetch_and_cache_service_token do
    token = case Prettycore.SysAdmin.get_config() do
      %{token: token} when is_binary(token) and token != "" -> token
      _ -> ""
    end
    :persistent_term.put(:cache_api_service_token, {token, System.monotonic_time(:millisecond)})
    token
  end

  # ============================================================
  # PUBLIC API - GET (SELECT)
  # ============================================================

  @doc """
  Obtiene todos los registros de una tabla.

  ## Ejemplos
      iex> Prettycore.Api.Client.get_all("CTE_TIPO")
      {:ok, [%{"CTETPO_CODIGO_K" => "100", ...}, ...]}

      iex> Prettycore.Api.Client.get_all("CTE_TIPO", "bearer_token")
      {:ok, [%{"CTETPO_CODIGO_K" => "100", ...}, ...]}
  """
  def get_all(table, auth_token \\ nil) when is_binary(table) do
    url = "#{base_url()}/#{table}"
    do_get(url, auth_token)
  end

  @doc """
  Obtiene registros filtrados de una tabla.
  Los filtros se envían en el body del POST request.

  ## Ejemplos
      iex> Prettycore.Api.Client.get_filtered("CTE_SUBCANAL", %{"CTECAN_CODIGO_K" => "01"})
      {:ok, [%{...}, ...]}
  """
  def get_filtered(table, filters, auth_token \\ nil) when is_binary(table) and is_map(filters) do
    url = "#{base_url()}/#{table}"
    do_post(url, filters, auth_token)
  end

  @doc """
  Obtiene un registro por su clave primaria.

  ## Ejemplos
      iex> Prettycore.Api.Client.get_by_id("CTE_CLIENTE", "CTECLI_CODIGO_K", "0001")
      {:ok, %{...}}
  """
  def get_by_id(table, pk_field, pk_value, auth_token \\ nil) do
    get_filtered(table, %{pk_field => pk_value}, auth_token)
    |> case do
      {:ok, [record | _]} -> {:ok, record}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Ejecuta una consulta SQL personalizada vía API (si está soportado).
  """
  def query(sql, auth_token \\ nil) when is_binary(sql) do
    url = "#{base_url()}/query"
    do_post(url, %{sql: sql}, auth_token)
  end

  # ============================================================
  # PUBLIC API - POST/PUT/DELETE
  # ============================================================

  @doc """
  Crea un nuevo registro en una tabla.
  """
  def create(table, data, auth_token \\ nil) do
    url = "#{base_url()}/#{table}"
    do_post(url, data, auth_token)
  end

  @doc """
  Actualiza un registro existente.
  """
  def update(table, data, auth_token \\ nil) do
    url = "#{base_url()}/#{table}"
    do_put(url, data, auth_token)
  end

  @doc """
  Elimina un registro.
  """
  def delete(table, pk_field, pk_value, auth_token \\ nil) do
    url = "#{base_url()}/#{table}?#{pk_field}=#{URI.encode_www_form(to_string(pk_value))}"
    do_delete(url, auth_token)
  end

  # ============================================================
  # HELPERS ESPECÍFICOS POR TABLA
  # ============================================================

  # --- Catálogos ---
  # Todas las funciones helper ahora soportan un token opcional como último parámetro

  def get_tipos_cliente(token \\ nil), do: get_all("CTE_TIPO", token)
  def get_canales(token \\ nil), do: get_all("CTE_CANAL", token)
  def get_subcanales(canal_codigo, token \\ nil), do: get_filtered("CTE_SUBCANAL", %{"CTECAN_CODIGO_K" => canal_codigo}, token)
  def get_regimenes(token \\ nil), do: get_all("CTE_REGIMEN", token)
  def get_cadenas(token \\ nil), do: get_all("CTE_CADENA", token)
  def get_paquetes_servicio(token \\ nil), do: get_all("CTE_PAQUETESERV", token)
 # def get_transacciones(token \\ nil), do: get_filtered("SYS_TRANSAC", %{"SYSTRA_TIPO" => "F"}, token)
  def get_monedas(token \\ nil), do: get_all("CFG_MONEDA", token)
  def get_rutas(token \\ nil), do: get_all("VTA_RUTA", token)

  # --- SAT ---

  def get_usos_cfdi(token \\ nil), do: get_all("CFG_USOCFDISAT", token)
  def get_formas_pago(token \\ nil), do: get_all("CFG_FORMAPAGO_SAT", token)
  def get_metodos_pago(token \\ nil), do: get_all("CFG_METODOPAGO", token)
  def get_regimenes_fiscales(token \\ nil), do: get_all("CFG_REGIMENFISCAL_SAT", token)

  # --- Estadísticas ---

  def get_estadisticas(cliente_codigo, dir_codigo, token \\ nil) do
    url = "#{base_url()}/Estadisticas"
    data = %{"CTECLI_CODIGO_K" => cliente_codigo, "CTEDIR_CODIGO_K" => dir_codigo}
    do_post(url, data, token)
  end

  def get_precios(cliente_codigo, dir_codigo, token \\ nil) do
    url = "#{base_url()}/VTA_PRECIOS"
    data = %{"CTECLI_CODIGO_K" => cliente_codigo, "CTEDIR_CODIGO_K" => dir_codigo}
    do_post(url, data, token)
  end

  # --- Clientes ---

  def get_productos(token \\ nil), do: get_all("PRO_PRODUCTO", token)

  def get_clientes(token \\ nil), do: get_all("CTE_CLIENTE", token)
  def get_cliente(codigo, token \\ nil), do: get_by_id("CTE_CLIENTE", "CTECLI_CODIGO_K", codigo, token)
  def get_direcciones_cliente(cliente_codigo, token \\ nil) do
    get_filtered("CTE_DIRECCION", %{"CTECLI_CODIGO_K" => cliente_codigo}, token)
  end

  # --- Usuarios ---

  def get_usuarios(token \\ nil), do: get_all("SYS_USUARIO", token)
  def get_usuario(codigo, token \\ nil), do: get_by_id("SYS_USUARIO", "SYSUSR_CODIGO_K", codigo, token)
  def get_xen_usuarios(token \\ nil), do: get_all("XEN_SYS_USUARIO", token)
  def get_xen_usuario(codigo, token \\ nil), do: get_by_id("XEN_SYS_USUARIO", "SYSUSR_CODIGO_K", codigo, token)

  @doc """
  Obtiene las credenciales de autenticación para el Usuario FROG.
  Envía: {"FG_USUARIO": "usuario_frog"}
  Recibe: {"SYSUSR_PASSWORD": "password_para_api"}
  """
  def get_frog_credentials(frog_usuario) when is_binary(frog_usuario) do
    url = "#{base_url()}/REST_USUARIO"
    data = %{"FG_USUARIO" => frog_usuario}

    headers = [
      {"accept", "application/json"},
      {"content-type", "application/json"},
      {"authorization", "Bearer #{service_token()}"}
    ]

    body = Jason.encode!(data)

    {elapsed_us, http_result} = :timer.tc(fn ->
      Req.post(url, body: body, headers: headers, receive_timeout: @timeout, retry: false)
    end)

    elapsed_ms = div(elapsed_us, 1000)
    Logger.debug("API FROG AUTH: #{url} user=#{frog_usuario} [#{elapsed_ms}ms]")

    case http_result do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        case parse_response(resp_body) do
          {:ok, %{"SYSUSR_PASSWORD" => password}} when is_binary(password) ->
            {:ok, password}

          {:ok, [%{"SYSUSR_PASSWORD" => password} | _]} when is_binary(password) ->
            {:ok, password}

          {:ok, other} ->
            Logger.error("FROG AUTH unexpected response: #{inspect(other)}")
            {:error, :invalid_response}
        end

      {:ok, %Req.Response{status: 401, body: resp_body}} ->
        Logger.error("FROG AUTH error 401: #{inspect(resp_body)}")
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.error("FROG AUTH error #{status}: #{inspect(resp_body)}")
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        Logger.error("FROG AUTH connection error: #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  end

  # --- Work Orders ---

  def get_workorders(token \\ nil), do: get_all("XEN_WOKORDERENC", token)
  def get_workorder(codigo, token \\ nil), do: get_by_id("XEN_WOKORDERENC", "XENWOE_CODIGO_K", codigo, token)
  def get_workorder_tipos(token \\ nil), do: get_all("XEN_WOKORDERTIPO", token)
  def get_workorder_detalles(workorder_codigo, token \\ nil) do
    get_filtered("XEN_WOKORDERDET", %{"XENWOE_CODIGO_K" => workorder_codigo}, token)
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp do_get(url, auth_token) do
    headers = build_headers(auth_token)

    {elapsed_us, result} = :timer.tc(fn ->
      Req.get(url, headers: headers, receive_timeout: @timeout, retry: false)
    end)

    elapsed_ms = div(elapsed_us, 1000)
    Logger.debug("API GET: #{url} [#{elapsed_ms}ms]")

    case result do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        parse_response(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("API GET error #{status}: #{url} [#{elapsed_ms}ms]")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("API GET connection error: #{url} [#{elapsed_ms}ms] #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  end

  defp do_post(url, data, auth_token) do
    headers = build_headers(auth_token)
    body = Jason.encode!(data)

    {elapsed_us, result} = :timer.tc(fn ->
      Req.post(url, body: body, headers: headers, receive_timeout: @timeout, retry: false)
    end)

    elapsed_ms = div(elapsed_us, 1000)
    Logger.debug("API POST: #{url} [#{elapsed_ms}ms]")

    case result do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        parse_response(resp_body)

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.error("API POST error #{status}: #{url} [#{elapsed_ms}ms]")
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        Logger.error("API POST connection error: #{url} [#{elapsed_ms}ms] #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  end

  defp do_put(url, data, auth_token) do
    headers = build_headers(auth_token)
    body = Jason.encode!(data)

    {elapsed_us, result} = :timer.tc(fn ->
      Req.put(url, body: body, headers: headers, receive_timeout: @timeout, retry: false)
    end)

    elapsed_ms = div(elapsed_us, 1000)
    Logger.debug("API PUT: #{url} [#{elapsed_ms}ms]")

    case result do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        parse_response(resp_body)

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.error("API PUT error #{status}: #{url} [#{elapsed_ms}ms]")
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        Logger.error("API PUT connection error: #{url} [#{elapsed_ms}ms] #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  end

  defp do_delete(url, auth_token) do
    headers = build_headers(auth_token)

    {elapsed_us, result} = :timer.tc(fn ->
      Req.delete(url, headers: headers, receive_timeout: @timeout, retry: false)
    end)

    elapsed_ms = div(elapsed_us, 1000)
    Logger.debug("API DELETE: #{url} [#{elapsed_ms}ms]")

    case result do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        Logger.error("API DELETE error #{status}: #{url} [#{elapsed_ms}ms]")
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        Logger.error("API DELETE connection error: #{url} [#{elapsed_ms}ms] #{inspect(reason)}")
        {:error, {:connection_error, reason}}
    end
  end

  defp build_headers(nil), do: build_headers(service_token())

  defp build_headers(auth_token) do
    [
      {"accept", "application/json"},
      {"content-type", "application/json"},
      {"authorization", "Bearer #{auth_token}"}
    ]
  end

  defp build_query_string(filters) do
    filters
    |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
    |> Enum.join("&")
  end

  defp parse_response(body) when is_list(body), do: {:ok, body}
  defp parse_response(body) when is_map(body), do: {:ok, body}
  defp parse_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, body}
    end
  end
  defp parse_response(body), do: {:ok, body}
end
