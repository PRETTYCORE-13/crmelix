defmodule Prettycore.Emails.BienvenidaCliente do
  import Swoosh.Email
  require Logger
  alias Prettycore.Mailer

  @from_email "servicio.cliente@ennovacore.com.mx"
  @from_name "PrettyCore"

  def send_reset_link(cliente_email, cliente_nombre, reset_url) do
    email_struct =
      new()
      |> to({cliente_nombre, cliente_email})
      |> from({@from_name, @from_email})
      |> subject("Restablecer contraseña — PrettyCore")
      |> html_body(html_reset_template(cliente_nombre, reset_url))
      |> text_body(text_reset_template(cliente_nombre, reset_url))

    case Mailer.deliver(email_struct) do
      {:ok, response} ->
        Logger.info("Email reset enviado a #{cliente_email}: #{inspect(response)}")
        {:ok, response}

      {:error, reason} ->
        Logger.error("Error enviando reset a #{cliente_email}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp html_reset_template(nombre, reset_url) do
    """
    <!DOCTYPE html>
    <html lang="es">
    <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f5f5f5;font-family:Arial,sans-serif;">
      <div style="max-width:600px;margin:0 auto;padding:32px 16px;">
        <div style="background:linear-gradient(135deg,#7c3aed,#4f46e5);border-radius:16px 16px 0 0;padding:32px;text-align:center;">
          <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700;letter-spacing:-0.5px;">PrettyCore</h1>
          <p style="color:rgba(255,255,255,0.8);margin:8px 0 0;font-size:14px;">Restablecer contraseña</p>
        </div>
        <div style="background:#fff;padding:32px;border-left:1px solid #e5e7eb;border-right:1px solid #e5e7eb;">
          <p style="color:#111827;font-size:16px;margin:0 0 8px;">Hola, <strong>#{nombre}</strong></p>
          <p style="color:#6b7280;font-size:14px;margin:0 0 28px;line-height:1.6;">
            Se ha solicitado restablecer tu contraseña. Haz clic en el siguiente botón para elegir una nueva contraseña. Este enlace es válido por 24 horas.
          </p>
          <div style="text-align:center;margin-bottom:28px;">
            <a href="#{reset_url}" style="display:inline-block;background:linear-gradient(135deg,#7c3aed,#4f46e5);color:#fff;text-decoration:none;font-size:14px;font-weight:700;padding:14px 32px;border-radius:50px;letter-spacing:0.02em;">
              Crear nueva contraseña
            </a>
          </div>
          <p style="color:#9ca3af;font-size:13px;margin:0;line-height:1.6;">
            Si no puedes hacer clic en el botón, copia y pega este enlace en tu navegador:<br>
            <span style="color:#4f46e5;word-break:break-all;">#{reset_url}</span>
          </p>
        </div>
        <div style="background:#f9fafb;border:1px solid #e5e7eb;border-top:0;border-radius:0 0 16px 16px;padding:20px 32px;text-align:center;">
          <p style="color:#9ca3af;font-size:12px;margin:0;">
            Si no solicitaste este cambio, puedes ignorar este correo.<br>
            &copy; #{DateTime.utc_now().year} PrettyCore. Todos los derechos reservados.
          </p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp text_reset_template(nombre, reset_url) do
    """
    Restablecer contraseña — PrettyCore

    Hola #{nombre},

    Se ha solicitado restablecer tu contraseña.
    Visita el siguiente enlace para crear una nueva (válido 24 horas):

    #{reset_url}

    Si no solicitaste este cambio, puedes ignorar este correo.

    © #{DateTime.utc_now().year} PrettyCore
    """
  end

  def send_credenciales(cliente_email, cliente_nombre, username, password) do
    email_struct =
      new()
      |> to({cliente_nombre, cliente_email})
      |> from({@from_name, @from_email})
      |> subject("Bienvenido a PrettyCore — Tus credenciales de acceso")
      |> html_body(html_template(cliente_nombre, username, password))
      |> text_body(text_template(cliente_nombre, username, password))

    case Mailer.deliver(email_struct) do
      {:ok, response} ->
        Logger.info("Email bienvenida enviado a #{cliente_email}: #{inspect(response)}")
        {:ok, response}

      {:error, reason} ->
        Logger.error("Error enviando bienvenida a #{cliente_email}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp html_template(nombre, username, password) do
    """
    <!DOCTYPE html>
    <html lang="es">
    <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f5f5f5;font-family:Arial,sans-serif;">
      <div style="max-width:600px;margin:0 auto;padding:32px 16px;">

        <!-- Header -->
        <div style="background:linear-gradient(135deg,#7c3aed,#4f46e5);border-radius:16px 16px 0 0;padding:32px;text-align:center;">
          <h1 style="color:#fff;margin:0;font-size:28px;font-weight:700;letter-spacing:-0.5px;">PrettyCore</h1>
          <p style="color:rgba(255,255,255,0.8);margin:8px 0 0;font-size:14px;">Tu cuenta ha sido creada</p>
        </div>

        <!-- Body -->
        <div style="background:#fff;padding:32px;border-left:1px solid #e5e7eb;border-right:1px solid #e5e7eb;">
          <p style="color:#111827;font-size:16px;margin:0 0 8px;">Hola, <strong>#{nombre}</strong></p>
          <p style="color:#6b7280;font-size:14px;margin:0 0 28px;line-height:1.6;">
            Tu cuenta en PrettyCore ha sido creada exitosamente. A continuación encontrarás tus credenciales de acceso.
          </p>

          <!-- Credenciales -->
          <div style="background:#f9fafb;border:1px solid #e5e7eb;border-radius:12px;padding:24px;margin-bottom:28px;">
            <p style="margin:0 0 16px;font-size:13px;font-weight:700;color:#374151;text-transform:uppercase;letter-spacing:0.05em;">Tus credenciales</p>
            <div style="display:flex;align-items:center;gap:12px;margin-bottom:12px;">
              <span style="font-size:12px;color:#6b7280;min-width:90px;">Usuario</span>
              <span style="font-family:monospace;font-size:15px;font-weight:700;color:#111827;background:#e5e7eb;padding:4px 12px;border-radius:6px;">#{username}</span>
            </div>
            <div style="display:flex;align-items:center;gap:12px;">
              <span style="font-size:12px;color:#6b7280;min-width:90px;">Contraseña</span>
              <span style="font-family:monospace;font-size:15px;font-weight:700;color:#111827;background:#e5e7eb;padding:4px 12px;border-radius:6px;">#{password}</span>
            </div>
          </div>

          <p style="color:#6b7280;font-size:13px;margin:0 0 28px;line-height:1.6;">
            Por seguridad, te recomendamos cambiar tu contraseña la primera vez que inicies sesión.
          </p>

          <!-- Botón Cambiar contraseña -->
          <div style="text-align:center;">
            <a href="#" style="display:inline-block;background:linear-gradient(135deg,#7c3aed,#4f46e5);color:#fff;text-decoration:none;font-size:14px;font-weight:700;padding:14px 32px;border-radius:50px;letter-spacing:0.02em;">
              Cambiar contraseña
            </a>
          </div>
        </div>

        <!-- Footer -->
        <div style="background:#f9fafb;border:1px solid #e5e7eb;border-top:0;border-radius:0 0 16px 16px;padding:20px 32px;text-align:center;">
          <p style="color:#9ca3af;font-size:12px;margin:0;">
            Si no esperabas este correo, puedes ignorarlo.<br>
            &copy; #{DateTime.utc_now().year} PrettyCore. Todos los derechos reservados.
          </p>
        </div>

      </div>
    </body>
    </html>
    """
  end

  defp text_template(nombre, username, password) do
    """
    Bienvenido a PrettyCore

    Hola #{nombre},

    Tu cuenta ha sido creada exitosamente.

    Tus credenciales de acceso:
    Usuario:     #{username}
    Contraseña:  #{password}

    Por seguridad, te recomendamos cambiar tu contraseña al iniciar sesión.

    © #{DateTime.utc_now().year} PrettyCore
    """
  end
end
