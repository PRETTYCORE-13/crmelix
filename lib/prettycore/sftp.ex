defmodule Prettycore.Sftp do
  @moduledoc """
  Sube imágenes al servidor SFTP y retorna la URL pública.
  Reintenta automáticamente hasta 2 veces si la conexión falla.
  """
  require Logger

  @host ~c"88.223.85.55"
  @port 65002
  @user ~c"u588009084"
  @password ~c"Poder316."
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

  def upload_producto_nativo_image(codigo, ext, content) when is_binary(content) do
    name = "#{codigo}#{ext}"
    upload("#{@dir_productos_nativos}/#{name}", "#{@url_productos_nativos}/#{name}", @make_dirs_productos_nativos, content, "producto_nativo")
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

  def upload_super_categoria_image(slug, ext, content) when is_binary(content) do
    name = "#{slug}#{ext}"
    upload("#{@dir_supercats}/#{name}", "#{@url_supercats}/#{name}", @make_dirs_supercats, content, "super_categoría")
  end

  # ── Privado ────────────────────────────────────────────────────────

  defp upload(remote_path, url, dirs, content, label, attempt \\ 1) do
    Logger.info("SFTP: subiendo #{label} → #{remote_path} (intento #{attempt})")

    opts = [
      user: @user,
      password: @password,
      silently_accept_hosts: true,
      user_interaction: false,
      connect_timeout: @timeout
    ]

    with {:ok, conn} <- :ssh.connect(@host, @port, opts, @timeout),
         {:ok, ch}   <- :ssh_sftp.start_channel(conn, timeout: @timeout) do
      Enum.each(dirs, &:ssh_sftp.make_dir(ch, &1))

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
