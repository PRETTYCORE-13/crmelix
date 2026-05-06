defmodule Prettycore.Sftp do
  @moduledoc """
  Sube imágenes al servidor SFTP y retorna la URL pública.
  Reintenta automáticamente hasta 2 veces si la conexión falla.
  """
  require Logger

  @host ~c"88.223.85.55"
  @port 65002
  @user ~c"u588009084"
  @password ~c"PRETTYCORe13."
  @timeout 20_000
  @retries 2

  @url_base       "https://prettycore.xyz/ELIXIR/PRETTYCORE"
  @url_cats       "https://prettycore.xyz/ELIXIR/PRETTYCORE/CATEGORIAS"
  @url_carrusel   "https://prettycore.xyz/ELIXIR/PRETTYCORE/CARRUSEL"
  @url_supercats  "https://prettycore.xyz/ELIXIR/PRETTYCORE/SUPERCATEGORIAS"

  @dir_base       "domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE"
  @dir_cats       "domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/CATEGORIAS"
  @dir_carrusel   "domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/CARRUSEL"
  @dir_supercats  "domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/SUPERCATEGORIAS"

  @make_dirs_base     [~c"domains/prettycore.xyz/public_html/ELIXIR", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE"]
  @make_dirs_cats     [~c"domains/prettycore.xyz/public_html/ELIXIR", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/CATEGORIAS"]
  @make_dirs_carrusel [~c"domains/prettycore.xyz/public_html/ELIXIR", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/CARRUSEL"]
  @make_dirs_supercats [~c"domains/prettycore.xyz/public_html/ELIXIR", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/SUPERCATEGORIAS"]

  @url_productos_nativos "https://prettycore.xyz/ELIXIR/PRETTYCORE/PRODUCTOS_NATIVOS"
  @dir_productos_nativos "domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/PRODUCTOS_NATIVOS"
  @make_dirs_productos_nativos [~c"domains/prettycore.xyz/public_html/ELIXIR", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/PRODUCTOS_NATIVOS"]

  @url_carrusel_dest   "https://prettycore.xyz/ELIXIR/PRETTYCORE/CARRUSEL_DESTACADOS"
  @dir_carrusel_dest   "domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/CARRUSEL_DESTACADOS"
  @make_dirs_carrusel_dest [~c"domains/prettycore.xyz/public_html/ELIXIR", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE", ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE/CARRUSEL_DESTACADOS"]

  def upload_producto_nativo_image(codigo, ext, content) when is_binary(content) do
    name = "#{codigo}#{ext}"
    upload("#{@dir_productos_nativos}/#{name}", "#{@url_productos_nativos}/#{name}", @make_dirs_productos_nativos, content, "producto_nativo")
  end

  @doc "Elimina un archivo remoto a partir de su URL pública. Ignora errores silenciosamente."
  def delete_by_url(nil), do: :ok
  def delete_by_url(""), do: :ok
  def delete_by_url(url) when is_binary(url) do
    prefix = "https://prettycore.xyz/"
    clean_url = url |> String.split("?") |> List.first()
    if String.starts_with?(clean_url, prefix) do
      relative = String.replace_prefix(clean_url, prefix, "")
      remote_path = "domains/prettycore.xyz/public_html/#{relative}"
      delete_remote(remote_path)
    else
      :ok
    end
  end

  defp delete_remote(remote_path) do
    opts = [
      user: @user,
      password: @password,
      silently_accept_hosts: true,
      user_interaction: false,
      auth_methods: ~c"password",
      connect_timeout: @timeout
    ]

    case :ssh.connect(@host, @port, opts, @timeout) do
      {:ok, conn} ->
        case :ssh_sftp.start_channel(conn, timeout: @timeout) do
          {:ok, ch} ->
            result = :ssh_sftp.delete(ch, String.to_charlist(remote_path))
            Logger.info("SFTP: delete #{remote_path} → #{inspect(result)}")
            :ssh_sftp.stop_channel(ch)
            :ssh.close(conn)
          _ ->
            :ok
        end
      _ ->
        :ok
    end
  end

  def upload_product_image(codigo, ext, content) when is_binary(content) do
    name = "#{codigo}#{ext}"
    upload("#{@dir_base}/#{name}", "#{@url_base}/#{name}", @make_dirs_base, content, "producto")
  end

  def upload_categoria_image(slug, ext, content) when is_binary(content) do
    name = "#{slug}#{ext}"
    upload("#{@dir_cats}/#{name}", "#{@url_cats}/#{name}", @make_dirs_cats, content, "categoría")
  end

  def upload_carrusel_image(filename, ext, content) when is_binary(content) do
    name = "#{filename}#{ext}"
    upload("#{@dir_carrusel}/#{name}", "#{@url_carrusel}/#{name}", @make_dirs_carrusel, content, "carrusel")
  end

  def upload_carrusel_destacados_image(filename, ext, content) when is_binary(content) do
    name = "#{filename}#{ext}"
    upload("#{@dir_carrusel_dest}/#{name}", "#{@url_carrusel_dest}/#{name}", @make_dirs_carrusel_dest, content, "carrusel_destacados")
  end

  def upload_super_categoria_image(slug, ext, content) when is_binary(content) do
    name = "#{slug}#{ext}"
    upload("#{@dir_supercats}/#{name}", "#{@url_supercats}/#{name}", @make_dirs_supercats, content, "super_categoría")
  end

  @doc "Prueba la conexión SFTP. Llama desde iex: Prettycore.Sftp.test_conexion()"
  def test_conexion do
    opts = [
      user: @user,
      password: @password,
      silently_accept_hosts: true,
      user_interaction: false,
      auth_methods: ~c"password",
      connect_timeout: 10_000
    ]
    IO.puts("Conectando a #{@host}:#{@port} como #{@user}...")
    case :ssh.connect(@host, @port, opts, 10_000) do
      {:ok, conn} ->
        IO.puts("✓ SSH conectado")
        case :ssh_sftp.start_channel(conn, timeout: 10_000) do
          {:ok, ch} ->
            IO.puts("✓ Canal SFTP abierto")
            case :ssh_sftp.list_dir(ch, ~c".", timeout: 10_000) do
              {:ok, entries} ->
                IO.puts("✓ Directorio raíz accesible, #{length(entries)} entradas")
              {:error, r} ->
                IO.puts("✗ list_dir falló: #{inspect(r)}")
            end
            :ssh_sftp.stop_channel(ch)
            :ssh.close(conn)
          {:error, r} ->
            IO.puts("✗ Canal SFTP falló: #{inspect(r)}")
            :ssh.close(conn)
        end
      {:error, reason} ->
        IO.puts("✗ Conexión SSH falló: #{inspect(reason)}")
    end
  end

  # ── Privado ────────────────────────────────────────────────────────

  defp upload(remote_path, url, dirs, content, label, attempt \\ 1) do
    Logger.info("SFTP: subiendo #{label} → #{remote_path} (intento #{attempt})")

    opts = [
      user: @user,
      password: @password,
      silently_accept_hosts: true,
      user_interaction: false,
      auth_methods: ~c"password",
      connect_timeout: @timeout
    ]

    with {:ok, conn} <- :ssh.connect(@host, @port, opts, @timeout),
         {:ok, ch}   <- :ssh_sftp.start_channel(conn, timeout: @timeout) do
      result =
        case :ssh_sftp.write_file(ch, String.to_charlist(remote_path), content) do
          :ok ->
            Logger.info("SFTP: #{label} subido OK → #{url}")
            {:ok, url}
          {:error, reason} ->
            Logger.error("SFTP: error al escribir #{label}: #{inspect(reason)}")
            {:error, inspect(reason)}
        end

      :ssh_sftp.stop_channel(ch)
      :ssh.close(conn)
      result
    else
      {:error, reason} ->
        Logger.warning("SFTP: fallo conexión #{label} (intento #{attempt}): #{inspect(reason)}")
        if attempt < @retries + 1 do
          Process.sleep(1_500 * attempt)
          upload(remote_path, url, dirs, content, label, attempt + 1)
        else
          Logger.error("SFTP: #{@retries + 1} intentos fallidos para #{label}")
          {:error, inspect(reason)}
        end
    end
  end
end
