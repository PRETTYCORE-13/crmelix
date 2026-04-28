defmodule PrettycoreWeb.ProductosNativosTemplateController do
  use PrettycoreWeb, :controller
  alias Elixlsx.{Workbook, Sheet}
  alias Prettycore.ProductosNativos

  def exportar(conn, _params) do
    col_headers =
      ["CODIGO", "PRECIO", "DESCRIPCION_LARGA", "NOMBRE",
       "UNIDAD", "MARCA", "CATEGORIA", "SUPER_CATEGORIA", "NOTAS", "IMAGEN_URL"]
      |> Enum.map(&[&1, bold: true, bg_color: "#4f46e5", color: "#ffffff"])

    rows =
      ProductosNativos.list_todos()
      |> Enum.map(fn p ->
        [
          p.codigo,
          p.precio_base || 0.0,
          p.descripcion || "",
          p.desc_corta || "",
          p.unidad || "",
          p.marca || "",
          p.categoria || "",
          p.super_categoria || "",
          p.notas || "",
          p.imagen_url || ""
        ]
      end)

    sheet = %Sheet{
      name: "Productos",
      rows: [col_headers] ++ rows,
      col_widths: %{1 => 15, 2 => 10, 3 => 40, 4 => 30,
                    5 => 10, 6 => 20, 7 => 20, 8 => 20, 9 => 30, 10 => 45}
    }

    {:ok, {_filename, binary}} = Elixlsx.write_to_memory(%Workbook{sheets: [sheet]}, "productos.xlsx")

    fecha = Date.utc_today() |> Date.to_string()

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="productos_#{fecha}.xlsx"))
    |> send_resp(200, binary)
  end

  def download(conn, _params) do
    headers = [
      ["CODIGO", "PRECIO", "DESCRIPCION_LARGA", "NOMBRE",
       "UNIDAD", "MARCA", "CATEGORIA", "SUPER_CATEGORIA", "NOTAS", "IMAGEN_URL"]
      |> Enum.map(&[&1, bold: true, bg_color: "#4f46e5", color: "#ffffff"])
    ]

    example = [["PROD-001", 99.99, "Refresco Coca Cola 600ml", "Presentación 600ml",
                 "PZA", "Coca-Cola", "Bebidas", "Lacteos", "", "https://ejemplo.com/imagen.jpg"]]


    sheet = %Sheet{name: "Productos", rows: headers ++ example,
                   col_widths: %{1 => 15, 2 => 10, 3 => 40, 4 => 30,
                                  5 => 10, 6 => 20, 7 => 20, 8 => 20, 9 => 30, 10 => 45}}

    workbook = %Workbook{sheets: [sheet]}
    {:ok, {_filename, binary}} = Elixlsx.write_to_memory(workbook, "plantilla.xlsx")

    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="plantilla_productos.xlsx"))
    |> send_resp(200, binary)
  end
end
