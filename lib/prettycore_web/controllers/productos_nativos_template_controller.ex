defmodule PrettycoreWeb.ProductosNativosTemplateController do
  use PrettycoreWeb, :controller
  alias Elixlsx.{Workbook, Sheet}
  alias Prettycore.{ProductosNativos, StockSucursal, ListasPrecios, Sucursales}

  @color_productos "#4f46e5"
  @color_stock     "#16a34a"
  @color_precios   "#d97706"

  # ── Plantilla vacía ──────────────────────────────────────────────────────────

  def download(conn, _params) do
    sucursales   = Sucursales.list_todas()
    lista_nums   = ListasPrecios.numeros_disponibles()

    workbook = %Workbook{sheets: [
      sheet_productos_template(),
      sheet_stock_template(sucursales),
      sheet_precios_template(lista_nums)
    ]}
    {:ok, {_, binary}} = Elixlsx.write_to_memory(workbook, "plantilla.xlsx")
    send_xlsx(conn, binary, "plantilla_productos.xlsx")
  end

  # ── Exportar datos actuales ──────────────────────────────────────────────────

  def exportar(conn, _params) do
    sucursales = Sucursales.list_todas()
    lista_nums = ListasPrecios.numeros_disponibles()
    productos  = ProductosNativos.list_todos()
    desc_map   = Map.new(productos, &{&1.codigo, &1.descripcion || ""})

    workbook = %Workbook{sheets: [
      sheet_productos_data(productos),
      sheet_stock_data(productos, sucursales),
      sheet_precios_data(productos, lista_nums, desc_map)
    ]}
    {:ok, {_, binary}} = Elixlsx.write_to_memory(workbook, "exportar.xlsx")
    fecha = Date.utc_today() |> Date.to_string()
    send_xlsx(conn, binary, "productos_#{fecha}.xlsx")
  end

  # ── Sheets de plantilla ──────────────────────────────────────────────────────

  defp sheet_productos_template do
    headers = row_header(["CODIGO", "PRECIO", "DESCRIPCION_LARGA", "NOMBRE",
                           "UNIDAD", "MARCA", "CATEGORIA", "SUPER_CATEGORIA",
                           "NOTAS", "IMAGEN_URL"], @color_productos)
    example = [["PROD-001", 99.99, "Refresco Coca Cola 600ml", "Coca Cola 600ml",
                "PZA", "Coca-Cola", "Bebidas", "Lacteos", "", "https://ejemplo.com/img.jpg"]]
    %Sheet{name: "Productos", rows: [headers | example],
           col_widths: %{1=>15, 2=>10, 3=>40, 4=>30, 5=>10, 6=>20, 7=>20, 8=>20, 9=>30, 10=>45}}
  end

  defp sheet_stock_template([]) do
    # Sin sucursales registradas: columnas de ejemplo
    suc_cols = ["SUC 1 | Ejemplo", "SUC 2 | Ejemplo"]
    headers  = row_header(["PRODUCTO_CODIGO", "DESCRIPCION_LARGA"] ++ suc_cols, @color_stock)
    example  = [["PROD-001", "Refresco Coca Cola 600ml", 0, 0]]
    widths   = col_widths_pivote(2, length(suc_cols))
    %Sheet{name: "Stock", rows: [headers | example], col_widths: widths}
  end
  defp sheet_stock_template(sucursales) do
    suc_cols = Enum.map(sucursales, fn s -> "SUC #{s.numero} | #{s.nombre}" end)
    headers  = row_header(["PRODUCTO_CODIGO", "DESCRIPCION_LARGA"] ++ suc_cols, @color_stock)
    example  = [["PROD-001", "Refresco Coca Cola 600ml"] ++ List.duplicate(0, length(sucursales))]
    widths   = col_widths_pivote(2, length(suc_cols))
    %Sheet{name: "Stock", rows: [headers | example], col_widths: widths}
  end

  defp sheet_precios_template([]) do
    lista_cols = ["LISTA 1", "LISTA 2"]
    headers    = row_header(["PRODUCTO_CODIGO", "DESCRIPCION_LARGA"] ++ lista_cols, @color_precios)
    example    = [["PROD-001", "Refresco Coca Cola 600ml", 0.0, 0.0]]
    widths     = col_widths_pivote(2, length(lista_cols))
    %Sheet{name: "Precios", rows: [headers | example], col_widths: widths}
  end
  defp sheet_precios_template(lista_nums) do
    lista_cols = Enum.map(lista_nums, fn n -> "LISTA #{n}" end)
    headers    = row_header(["PRODUCTO_CODIGO", "DESCRIPCION_LARGA"] ++ lista_cols, @color_precios)
    example    = [["PROD-001", "Refresco Coca Cola 600ml"] ++ List.duplicate(0.0, length(lista_nums))]
    widths     = col_widths_pivote(2, length(lista_cols))
    %Sheet{name: "Precios", rows: [headers | example], col_widths: widths}
  end

  # ── Sheets con datos reales ──────────────────────────────────────────────────

  defp sheet_productos_data(productos) do
    headers = row_header(["CODIGO", "PRECIO", "DESCRIPCION_LARGA", "NOMBRE",
                           "UNIDAD", "MARCA", "CATEGORIA", "SUPER_CATEGORIA",
                           "NOTAS", "IMAGEN_URL"], @color_productos)
    rows = Enum.map(productos, fn p ->
      [p.codigo, p.precio_base || 0.0, p.descripcion || "", p.desc_corta || "",
       p.unidad || "", p.marca || "", p.categoria || "", p.super_categoria || "",
       p.notas || "", p.imagen_url || ""]
    end)
    %Sheet{name: "Productos", rows: [headers | rows],
           col_widths: %{1=>15, 2=>10, 3=>40, 4=>30, 5=>10, 6=>20, 7=>20, 8=>20, 9=>30, 10=>45}}
  end

  defp sheet_stock_data(productos, sucursales) do
    suc_cols   = Enum.map(sucursales, fn s -> "SUC #{s.numero} | #{s.nombre}" end)
    headers    = row_header(["PRODUCTO_CODIGO", "DESCRIPCION_LARGA"] ++ suc_cols, @color_stock)
    stock_maps = Map.new(sucursales, fn s -> {s.numero, StockSucursal.get_stock_map(s.numero)} end)

    rows = Enum.map(productos, fn p ->
      cantidades = Enum.map(sucursales, fn s ->
        Map.get(stock_maps[s.numero], p.codigo, 0)
      end)
      [p.codigo, p.descripcion || ""] ++ cantidades
    end)

    widths = col_widths_pivote(2, length(suc_cols))
    %Sheet{name: "Stock", rows: [headers | rows], col_widths: widths}
  end

  defp sheet_precios_data(productos, lista_nums, desc_map) do
    lista_cols  = Enum.map(lista_nums, fn n -> "LISTA #{n}" end)
    headers     = row_header(["PRODUCTO_CODIGO", "DESCRIPCION_LARGA"] ++ lista_cols, @color_precios)
    precio_maps = Map.new(lista_nums, fn n -> {n, ListasPrecios.get_precios_map(n)} end)

    rows = Enum.map(productos, fn p ->
      precios = Enum.map(lista_nums, fn n ->
        Map.get(precio_maps[n], p.codigo, 0.0)
      end)
      [p.codigo, Map.get(desc_map, p.codigo, "")] ++ precios
    end)

    widths = col_widths_pivote(2, length(lista_cols))
    %Sheet{name: "Precios", rows: [headers | rows], col_widths: widths}
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp row_header(cols, color),
    do: Enum.map(cols, &[&1, bold: true, bg_color: color, color: "#ffffff"])

  defp col_widths_pivote(fixed_cols, dynamic_cols) do
    fixed  = %{1 => 20, 2 => 40}
    dynamic =
      Enum.into(1..max(dynamic_cols, 1), %{}, fn i ->
        {fixed_cols + i, 15}
      end)
    Map.merge(fixed, dynamic)
  end

  defp send_xlsx(conn, binary, filename) do
    conn
    |> put_resp_content_type("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, binary)
  end
end
