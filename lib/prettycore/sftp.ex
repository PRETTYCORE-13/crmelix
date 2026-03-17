defmodule Prettycore.Sftp do
  @moduledoc """
  Sube imágenes de productos al servidor SFTP y retorna la URL pública.

  Servidor: 88.223.85.55:65002
  Ruta remota: public_html/ELIXIR/PRETTYCORE/{codigo}{ext}
  URL pública: https://prettycore.xyz/ELIXIR/PRETTYCORE/{codigo}{ext}
  """
  require Logger

  @host ~c"88.223.85.55"
  @port 65002
  @user ~c"u588009084"
  @password ~c"Poder316."
  @remote_dir "domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE"
  @url_base "https://prettycore.xyz/ELIXIR/PRETTYCORE"
  @timeout 20_000

  @doc """
  Sube el contenido binario de una imagen al SFTP.

  - `codigo`: código del producto (e.g. "ABC123")
  - `ext`: extensión con punto (e.g. ".jpg")
  - `content`: binario del archivo

  Retorna `{:ok, url}` o `{:error, reason}`.
  """
  def upload_product_image(codigo, ext, content) when is_binary(content) do
    safe_name = "#{codigo}#{ext}"
    remote_path = "#{@remote_dir}/#{safe_name}"
    url = "#{@url_base}/#{safe_name}"

    opts = [
      user: @user,
      password: @password,
      silently_accept_hosts: true,
      user_interaction: false,
      connect_timeout: @timeout
    ]

    Logger.info("SFTP: conectando a #{@host}:#{@port} para subir #{remote_path}")

    with {:ok, conn} <- :ssh.connect(@host, @port, opts, @timeout),
         {:ok, ch} <- :ssh_sftp.start_channel(conn, timeout: @timeout) do
      # Crear carpetas nivel por nivel (ignorar errores si ya existen)
      :ssh_sftp.make_dir(ch, ~c"domains/prettycore.xyz/public_html/ELIXIR")
      :ssh_sftp.make_dir(ch, ~c"domains/prettycore.xyz/public_html/ELIXIR/PRETTYCORE")

      result =
        case :ssh_sftp.write_file(ch, String.to_charlist(remote_path), content) do
          :ok ->
            Logger.info("SFTP: imagen subida OK → #{url}")
            {:ok, url}
          {:error, reason} ->
            Logger.error("SFTP: error al escribir archivo: #{inspect(reason)}")
            {:error, inspect(reason)}
        end

      :ssh_sftp.stop_channel(ch)
      :ssh.close(conn)
      result
    else
      {:error, reason} ->
        Logger.error("SFTP: error al conectar #{@host}:#{@port} → #{inspect(reason)}")
        {:error, inspect(reason)}
    end
  end
end
