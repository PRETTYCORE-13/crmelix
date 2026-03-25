defmodule PrettycoreWeb.ArchitectureExcelController do
  use PrettycoreWeb, :controller

  alias Prettycore.ArchitectureScanner
  alias Prettycore.ArchitectureExcel

  @doc "Genera y descarga el Excel de arquitectura. Solo accesible por sysadmin."
  def download(conn, _params) do
    case get_session(conn, :role) do   # la sesión usa :role (ver session_controller.ex)
      "sysadmin" ->
        result  = ArchitectureScanner.scan()
        binary  = ArchitectureExcel.generate(result)
        ts      = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M")
        filename = "architecture_scan_#{ts}.xlsx"

        conn
        |> put_resp_content_type(
             "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
             "utf-8"
           )
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> put_resp_header("content-transfer-encoding", "binary")
        |> put_resp_header("x-scan-funcionalidades", to_string(result.funcionalidades))
        |> put_resp_header("x-scan-tablas",          to_string(result.tablas))
        |> send_resp(200, binary)

      _ ->
        conn
        |> put_status(403)
        |> text("Acceso denegado")
    end
  end
end
