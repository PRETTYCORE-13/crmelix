defmodule Prettycore.ArchitectureExcel do
  @moduledoc """
  Genera el archivo Excel (.xlsx) con el contrato oficial de 13 columnas.

  Estructura del archivo:
    Hoja 1 "Resumen"  — metadatos del scan
    Hoja 2 "Datos"    — todas las filas con las 13 columnas exactas (contrato público)

  Contrato de columnas (orden fijo, sensible a posición para readers externos):
    Col  1  ID
    Col  2  Modulo
    Col  3  Funcionalidad
    Col  4  Tipo
    Col  5  Archivo
    Col  6  Tabla
    Col  7  TablaRelacionada
    Col  8  TipoRelacion
    Col  9  DependenciaDe
    Col 10  Descripcion
    Col 11  Orden
    Col 12  Version
    Col 13  FechaScan
  """

  alias Elixlsx.{Workbook, Sheet}

  @header_style  [bold: true, bg_color: "#1e293b", color: "#ffffff",  font_size: 10]
  @meta_key      [bold: true, bg_color: "#e2e8f0", color: "#0f172a",  font_size: 10]
  @normal        [font_size: 9]
  @mono          [font_size: 9, font: "Courier New"]

  # Ancho de cada columna en el orden exacto del contrato
  @col_widths %{1 => 6, 2 => 42, 3 => 16, 4 => 14, 5 => 52,
                6 => 22, 7 => 36, 8 => 18, 9 => 32,
                10 => 38, 11 => 8, 12 => 10, 13 => 22}

  # ── Punto de entrada ─────────────────────────────────────────────────────────

  def generate(%{rows: rows, funcionalidades: total_f, tablas: total_t, timestamp: ts}) do
    workbook = %Workbook{
      sheets: [
        sheet_resumen(total_f, total_t, ts, length(rows)),
        sheet_datos(rows)
      ]
    }

    {:ok, {_filename, binary}} = Elixlsx.write_to_memory(workbook, "architecture.xlsx")
    binary
  end

  # ── Hoja 1: Resumen ───────────────────────────────────────────────────────────

  defp sheet_resumen(total_f, total_t, ts, total_rows) do
    rows = [
      [["Arquitectura del Proyecto Phoenix", bold: true, font_size: 14]],
      [],
      [["Generado el",                  @meta_key], [ts,                    @normal]],
      [["Total filas en Datos",          @meta_key], [to_string(total_rows), @normal]],
      [["Funcionalidades detectadas",    @meta_key], [to_string(total_f),    bold: true, font_size: 10]],
      [["Tablas / Migraciones",          @meta_key], [to_string(total_t),    bold: true, font_size: 10]],
      [],
      [["Contrato de columnas (hoja Datos)", bold: true, font_size: 11]],
      [],
      [["#",  @header_style], ["Columna",         @header_style], ["Descripción",                          @header_style]],
      [["1",  @normal], ["ID",              @normal], ["Entero secuencial único por fila",     @normal]],
      [["2",  @normal], ["Modulo",          @normal], ["Nombre completo del módulo Elixir",    @normal]],
      [["3",  @normal], ["Funcionalidad",   @normal], ["Categoría: LiveView, Controller…",     @normal]],
      [["4",  @normal], ["Tipo",            @normal], ["Tipo detallado (mismo valor inicial)", @normal]],
      [["5",  @normal], ["Archivo",         @normal], ["Ruta relativa al proyecto",            @normal]],
      [["6",  @normal], ["Tabla",           @normal], ["Tabla de BD mapeada (Schemas)",        @normal]],
      [["7",  @normal], ["TablaRelacionada",@normal], ["Módulos destino de relaciones",        @normal]],
      [["8",  @normal], ["TipoRelacion",    @normal], ["belongs_to / has_many / etc.",         @normal]],
      [["9",  @normal], ["DependenciaDe",   @normal], ["Namespace padre del módulo",           @normal]],
      [["10", @normal], ["Descripcion",     @normal], ["Descripción auto-generada",            @normal]],
      [["11", @normal], ["Orden",           @normal], ["Orden de aparición (reservado)",       @normal]],
      [["12", @normal], ["Version",         @normal], ["Versión de la app en el momento del scan", @normal]],
      [["13", @normal], ["FechaScan",       @normal], ["Timestamp UTC del scan",               @normal]]
    ]

    %Sheet{name: "Resumen", rows: rows, col_widths: %{1 => 5, 2 => 20, 3 => 45}}
  end

  # ── Hoja 2: Datos (contrato público, 13 columnas exactas) ────────────────────

  defp sheet_datos(rows) do
    headers = [
      ["ID",              @header_style],
      ["Modulo",          @header_style],
      ["Funcionalidad",   @header_style],
      ["Tipo",            @header_style],
      ["Archivo",         @header_style],
      ["Tabla",           @header_style],
      ["TablaRelacionada",@header_style],
      ["TipoRelacion",    @header_style],
      ["DependenciaDe",   @header_style],
      ["Descripcion",     @header_style],
      ["Orden",           @header_style],
      ["Version",         @header_style],
      ["FechaScan",       @header_style]
    ]

    data_rows = Enum.map(rows, fn r ->
      [
        [to_string(r.id),          @normal],  # 1  ID
        [r.modulo,                 @normal],  # 2  Modulo
        [r.funcionalidad,          @normal],  # 3  Funcionalidad
        [r.tipo,                   @normal],  # 4  Tipo
        [r.archivo,                @mono],    # 5  Archivo
        [r.tabla,                  @mono],    # 6  Tabla
        [r.tabla_relacionada,      @normal],  # 7  TablaRelacionada
        [r.tipo_relacion,          @normal],  # 8  TipoRelacion
        [r.dependencia_de,         @normal],  # 9  DependenciaDe
        [r.descripcion,            @normal],  # 10 Descripcion
        [to_string(r.orden),       @normal],  # 11 Orden
        [r.version,                @normal],  # 12 Version
        [r.fecha_scan,             @normal]   # 13 FechaScan
      ]
    end)

    %Sheet{name: "Datos", rows: [headers | data_rows], col_widths: @col_widths}
  end
end
