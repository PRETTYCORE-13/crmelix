defmodule PrettycoreWeb.ProductosNativosLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.ProductosNativos

  alias Prettycore.Sftp
  alias Prettycore.Categorias
  alias Prettycore.SuperCategorias

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, "productos_nativos")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, true)
     |> assign(:sidebar_open, true)
     |> assign(:productos, [])
     |> assign(:search, "")
     |> assign(:modal, nil)          # nil | :nuevo | :editar
     |> assign(:selected, nil)
     |> assign(:form_codigo, "")
     |> assign(:form_descripcion, "")
     |> assign(:form_desc_corta, "")
     |> assign(:form_precio, "")
     |> assign(:form_stock, "")
     |> assign(:form_unidad, "PZA")
     |> assign(:form_marca, "")
     |> assign(:form_notas, "")
     |> assign(:form_activo, true)
     |> assign(:form_categoria, "")
     |> assign(:form_super_categoria, "")
     |> assign(:categorias_list, Categorias.list_categorias() |> Enum.map(& &1.nombre) |> Enum.reject(&(&1 in ["Todos", "Inicio"])))
     |> assign(:super_categorias_list, SuperCategorias.list_super_categorias() |> Enum.map(& &1.nombre))
     |> assign(:form_imagen_url, "")
     |> assign(:form_error, nil)
     |> assign(:upload_error, nil)
     |> assign(:uploading, false)
     |> assign(:subiendo_imagen, false)
     |> assign(:imagen_previews, %{})
     |> assign(:import_modal, false)
     |> assign(:import_result, nil)
     |> assign(:imagen_modo, "archivo")
     |> allow_upload(:imagen,
         accept: ~w(.jpg .jpeg .png .webp .gif),
         max_entries: 1,
         max_file_size: 10_000_000)
     |> allow_upload(:csv_importar,
         accept: ~w(.csv .xlsx),
         max_entries: 1,
         max_file_size: 5_000_000)
     |> load_productos()}
  end

  defp load_productos(socket) do
    q = socket.assigns[:search] || ""
    productos = if q == "", do: ProductosNativos.list_todos(), else: ProductosNativos.search(q)
    assign(socket, :productos, productos)
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket, "productos_nativos")
  end

  # ── Búsqueda ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_productos()}
  end

  # ── Importación masiva ────────────────────────────────────────────────────────

  @impl true
  def handle_event("abrir_importar", _, socket) do
    {:noreply, assign(socket, import_modal: true, import_result: nil)}
  end

  @impl true
  def handle_event("cerrar_importar", _, socket) do
    {:noreply, assign(socket, import_modal: false, import_result: nil)}
  end

  @impl true
  def handle_event("importar_csv", _params, socket) do
    results =
      consume_uploaded_entries(socket, :csv_importar, fn %{path: tmp_path}, entry ->
        ext = entry.client_name |> Path.extname() |> String.downcase()
        result = case ext do
          ".xlsx" ->
            binary = File.read!(tmp_path)
            sheets = leer_xlsx_sheets(binary)
            %{
              productos:  procesar_filas(Map.get(sheets, "productos", [])),
              stock:      procesar_stock_filas(Map.get(sheets, "stock", [])),
              precios:    procesar_precios_filas(Map.get(sheets, "precios", [])),
              sucursales: nil
            }
          _ ->
            filas = tmp_path |> File.read!() |> leer_csv()
            %{productos: procesar_filas(filas), stock: nil, precios: nil, sucursales: nil}
        end
        {:ok, result}
      end)

    case results do
      [result] ->
        hay_productos = result.productos.nuevos + result.productos.actualizados > 0
        socket = if hay_productos, do: load_productos(socket), else: socket
        {:noreply, assign(socket, import_result: result)}
      _ ->
        {:noreply, put_flash(socket, :error, "No se recibió ningún archivo")}
    end
  end

  # ── Lectores de archivo ───────────────────────────────────────────────────────

  defp leer_csv(content) do
    sep = if String.contains?(content, ";"), do: ";", else: ","

    content
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n", trim: true)
    |> then(fn [_header | rows] -> rows end)
    |> Enum.map(fn line ->
      line
      |> String.split(sep)
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.trim(&1, "\""))
    end)
  end

  # Sheet order: 1=Productos, 2=Stock, 3=Precios, 4=Sucursales
  @xlsx_tipos ~w(productos stock precios)

  defp leer_xlsx_sheets(binary) do
    case :zip.unzip(binary, [:memory]) do
      {:ok, files} ->
        map = Map.new(files, fn {name, data} -> {List.to_string(name), data} end)
        shared = map |> Map.get("xl/sharedStrings.xml", "") |> xlsx_shared_strings()

        map
        |> Map.keys()
        |> Enum.filter(&Regex.match?(~r|xl/worksheets/sheet\d+\.xml$|, &1))
        |> Enum.sort_by(fn path ->
          case Regex.run(~r/sheet(\d+)\.xml$/, path) do
            [_, n] -> String.to_integer(n)
            _      -> 999
          end
        end)
        |> Enum.with_index()
        |> Enum.flat_map(fn {path, i} ->
          tipo = Enum.at(@xlsx_tipos, i)
          if tipo do
            rows = map |> Map.get(path, "") |> xlsx_filas(shared)
            [{tipo, rows}]
          else
            []
          end
        end)
        |> Map.new()

      {:error, _} -> %{}
    end
  end

  defp xlsx_shared_strings(""), do: []
  defp xlsx_shared_strings(xml) do
    Regex.scan(~r/<si>.*?<t[^>]*>(.*?)<\/t>.*?<\/si>/s, xml)
    |> Enum.map(fn [_, t] -> xml_decode(t) end)
  end

  defp xlsx_filas("", _), do: []
  defp xlsx_filas(xml, shared) do
    Regex.scan(~r/<row\b[^>]*>(.*?)<\/row>/s, xml)
    |> Enum.map(fn [_, row] -> xlsx_celda_row(row, shared) end)
  end

  defp xlsx_celda_row(row_xml, shared) do
    cells =
      Regex.scan(~r/<c\b([^>]*)>(.*?)<\/c>/s, row_xml)
      |> Enum.flat_map(fn [_, attrs, content] ->
        case Regex.run(~r/\br="([A-Z]+)\d+"/, attrs) do
          [_, col_ref] ->
            idx  = col_ref |> String.to_charlist() |> Enum.reduce(0, fn c, acc -> acc * 26 + (c - ?A + 1) end)
            tipo = case Regex.run(~r/\bt="([^"]+)"/, attrs), do: ([_, t] -> t; nil -> "n")
            val  = xlsx_valor(content, tipo, shared)
            [{idx, val}]
          nil -> []
        end
      end)
      |> Map.new()

    max_col = if map_size(cells) == 0, do: 0, else: cells |> Map.keys() |> Enum.max()
    if max_col == 0, do: [], else: Enum.map(1..max_col, &Map.get(cells, &1, ""))
  end

  defp xlsx_valor(content, "s", shared) do
    case Regex.run(~r/<v>(\d+)<\/v>/, content) do
      [_, i] -> Enum.at(shared, String.to_integer(i), "")
      nil    -> ""
    end
  end
  defp xlsx_valor(content, "inlineStr", _) do
    case Regex.run(~r/<t[^>]*>(.*?)<\/t>/s, content) do
      [_, t] -> xml_decode(t)
      nil    -> ""
    end
  end
  defp xlsx_valor(content, _, _) do
    case Regex.run(~r/<v>(.*?)<\/v>/, content) do
      [_, v] -> v
      nil    -> ""
    end
  end

  defp xml_decode(t) do
    t
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
  end

  # ── Procesador de filas (común para CSV y XLSX) ───────────────────────────────

  defp procesar_filas(filas) do
    parsed =
      filas
      |> Enum.with_index(2)
      |> Enum.map(fn {cols, row_num} -> validar_fila(cols, row_num) end)

    errores_validacion = for {:error, msg} <- parsed, do: msg

    if errores_validacion != [] do
      %{nuevos: 0, actualizados: 0, errores: errores_validacion, bloqueado: true}
    else
      Enum.reduce(parsed, %{nuevos: 0, actualizados: 0, errores: [], bloqueado: false}, fn
        {:ok, attrs}, acc ->
          case ProductosNativos.upsert_desde_importacion(attrs) do
            {:ok, :nuevo}       -> %{acc | nuevos: acc.nuevos + 1}
            {:ok, :actualizado} -> %{acc | actualizados: acc.actualizados + 1}
            {:error, msg}       -> %{acc | errores: acc.errores ++ ["#{attrs["codigo"]}: #{msg}"]}
          end
        {:warning, msg, attrs}, acc ->
          case ProductosNativos.upsert_desde_importacion(attrs) do
            {:ok, :nuevo}       -> %{acc | nuevos: acc.nuevos + 1,       errores: acc.errores ++ ["⚠ #{msg}"]}
            {:ok, :actualizado} -> %{acc | actualizados: acc.actualizados + 1, errores: acc.errores ++ ["⚠ #{msg}"]}
            {:error, e}         -> %{acc | errores: acc.errores ++ ["#{attrs["codigo"]}: #{e}"]}
          end
        {:skip, _}, acc -> acc
      end)
    end
  end

  # Formato pivote: primera fila = encabezados con números de sucursal, resto = datos
  defp procesar_stock_filas([]), do: %{procesados: 0, errores: [], bloqueado: false}
  defp procesar_stock_filas([header | data_rows]) do
    # Extrae números de sucursal de las columnas 3+ del encabezado
    suc_nums =
      header
      |> Enum.drop(2)
      |> Enum.flat_map(fn h ->
        case Regex.run(~r/\d+/, to_string(h)) do
          [n] -> [String.to_integer(n)]
          nil -> []
        end
      end)

    data_rows
    |> Enum.with_index(2)
    |> Enum.reduce(%{procesados: 0, errores: [], bloqueado: false}, fn {cols, _row_num}, acc ->
      [codigo | rest] = pad_list(cols, 2 + length(suc_nums))
      codigo = String.upcase(String.trim(to_string(codigo)))
      if codigo == "" do
        acc
      else
        cantidades = Enum.drop(rest, 1)  # saltar columna DESCRIPCION_LARGA
        suc_nums
        |> Enum.zip(cantidades)
        |> Enum.reduce(acc, fn {suc_num, val}, inner ->
          case Float.parse(String.trim(to_string(val))) do
            {f, _} ->
              Prettycore.StockSucursal.upsert_stock(codigo, suc_num, round(f))
              %{inner | procesados: inner.procesados + 1}
            :error -> inner
          end
        end)
      end
    end)
  end

  # Formato pivote: primera fila = encabezados con números de lista, resto = datos
  defp procesar_precios_filas([]), do: %{procesados: 0, errores: [], bloqueado: false}
  defp procesar_precios_filas([header | data_rows]) do
    # Extrae números de lista de las columnas 3+ del encabezado
    lista_nums =
      header
      |> Enum.drop(2)
      |> Enum.flat_map(fn h ->
        case Regex.run(~r/\d+/, to_string(h)) do
          [n] -> [String.to_integer(n)]
          nil -> []
        end
      end)

    data_rows
    |> Enum.with_index(2)
    |> Enum.reduce(%{procesados: 0, errores: [], bloqueado: false}, fn {cols, _row_num}, acc ->
      [codigo | rest] = pad_list(cols, 2 + length(lista_nums))
      codigo = String.upcase(String.trim(to_string(codigo)))
      if codigo == "" do
        acc
      else
        precios = Enum.drop(rest, 1)  # saltar columna DESCRIPCION_LARGA
        lista_nums
        |> Enum.zip(precios)
        |> Enum.reduce(acc, fn {lista_num, val}, inner ->
          str = val |> to_string() |> String.trim() |> String.replace(",", ".")
          case Float.parse(str) do
            {f, _} ->
              Prettycore.ListasPrecios.upsert_precio(lista_num, codigo, f)
              %{inner | procesados: inner.procesados + 1}
            :error -> inner
          end
        end)
      end
    end)
  end

  defp validar_fila(cols, row_num) do
    [codigo, precio_str | rest] = pad_list(cols, 10)

    codigo = String.upcase(String.trim(codigo))

    if codigo == "" or codigo == "CODIGO" do
      {:skip, :header_or_empty}
    else
      [desc_larga, desc_corta, unidad, marca, categoria, super_cat, notas, imagen_url] =
        pad_list(rest, 8)

      precio =
        precio_str
        |> String.replace(",", ".")
        |> Float.parse()
        |> case do
          {f, _} -> f
          :error  -> nil
        end

      campos_vacios =
        [
          {"CODIGO", codigo},
          {"PRECIO", if(is_nil(precio), do: "", else: "ok")},
          {"DESCRIPCION_LARGA", desc_larga},
          {"NOMBRE", desc_corta},
          {"UNIDAD", unidad},
          {"MARCA", marca},
          {"CATEGORIA", categoria},
          {"SUPER_CATEGORIA", super_cat}
        ]
        |> Enum.filter(fn {_, v} -> String.trim(v) == "" end)
        |> Enum.map(fn {campo, _} -> campo end)

      cond do
        campos_vacios != [] ->
          {:error, "Fila #{row_num} (#{codigo}): campos obligatorios vacíos → #{Enum.join(campos_vacios, ", ")}"}
        precio < 0 ->
          {:error, "Fila #{row_num} (#{codigo}): PRECIO negativo ($#{precio}) — no se permite importar productos con precio negativo"}
        true ->
          attrs = %{
            "codigo"          => codigo,
            "descripcion"     => nilify_str(desc_larga) || codigo,
            "desc_corta"      => nilify_str(desc_corta),
            "precio_base"     => precio,
            "unidad"          => nilify_str(unidad) || "PZA",
            "marca"           => nilify_str(marca),
            "categoria"       => nilify_str(categoria),
            "super_categoria" => nilify_str(super_cat),
            "notas"           => nilify_str(notas),
            "imagen_url"      => nilify_str(imagen_url),
            "activo"          => true
          }
          if precio == 0.0 do
            {:warning, "Fila #{row_num} (#{codigo}): PRECIO = $0.00 — se importará pero no podrá pedirse en tienda", attrs}
          else
            {:ok, attrs}
          end
      end
    end
  end

  defp pad_list(list, n) do
    list ++ List.duplicate("", max(0, n - length(list)))
  end

  defp nilify_str(s) do
    t = String.trim(s)
    if t == "", do: nil, else: t
  end

  # ── Modales ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("nuevo", _, socket) do
    {:noreply, socket
     |> assign(:modal, :nuevo)
     |> assign(:selected, nil)
     |> assign(:form_codigo, ProductosNativos.next_codigo())
     |> assign(:form_descripcion, "")
     |> assign(:form_desc_corta, "")
     |> assign(:form_precio, "")
     |> assign(:form_stock, "")
     |> assign(:form_unidad, "PZA")
     |> assign(:form_marca, "")
     |> assign(:form_notas, "")
     |> assign(:form_activo, true)
     |> assign(:form_categoria, "")
     |> assign(:form_super_categoria, "")
     |> assign(:form_imagen_url, "")
     |> assign(:imagen_modo, "archivo")
     |> assign(:categorias_list, Categorias.list_categorias() |> Enum.map(& &1.nombre) |> Enum.reject(&(&1 in ["Todos", "Inicio"])))
     |> assign(:super_categorias_list, SuperCategorias.list_super_categorias() |> Enum.map(& &1.nombre))
     |> assign(:form_error, nil)
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("editar", %{"codigo" => codigo}, socket) do
    case ProductosNativos.get(codigo) do
      nil -> {:noreply, socket}
      p ->
        {:noreply, socket
         |> assign(:modal, :editar)
         |> assign(:selected, p)
         |> assign(:form_codigo, p.codigo)
         |> assign(:form_descripcion, p.descripcion)
         |> assign(:form_desc_corta, p.desc_corta || "")
         |> assign(:form_precio, to_string(p.precio_base))
         |> assign(:form_stock, if(p.stock, do: to_string(p.stock), else: ""))
         |> assign(:form_unidad, p.unidad || "PZA")
         |> assign(:form_marca, p.marca || "")
         |> assign(:form_notas, p.notas || "")
         |> assign(:form_activo, p.activo)
         |> assign(:form_categoria, p.categoria || "")
         |> assign(:form_super_categoria, p.super_categoria || "")
         |> assign(:form_imagen_url, p.imagen_url || "")
         |> assign(:imagen_modo, "archivo")
         |> assign(:categorias_list, Categorias.list_categorias() |> Enum.map(& &1.nombre) |> Enum.reject(&(&1 in ["Todos", "Inicio"])))
         |> assign(:super_categorias_list, SuperCategorias.list_super_categorias() |> Enum.map(& &1.nombre))
         |> assign(:form_error, nil)
         |> assign(:upload_error, nil)}
    end
  end

  @impl true
  def handle_event("cerrar_modal", _, socket) do
    if socket.assigns.uploads.imagen.entries != [] do
      {:noreply, assign(socket, form_error: "Guarda o cancela la imagen antes de cerrar.")}
    else
      {:noreply, assign(socket, modal: nil, selected: nil, form_error: nil, upload_error: nil)}
    end
  end

  @impl true
  def handle_event("toggle_activo_form", _, socket) do
    {:noreply, update(socket, :form_activo, &(not &1))}
  end

  # ── Guardar ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("guardar", params, socket) do
    codigo = String.trim(params["codigo"] || socket.assigns.form_codigo)

    # Leer archivo ahora (consume_uploaded_entries debe llamarse en handle_event)
    # y decidir qué imagen URL guardar inmediatamente vs subir en background
    {imagen_url, pending_upload} =
      case {socket.assigns[:imagen_modo], socket.assigns.uploads.imagen.entries} do
        {"url", _} ->
          url = String.trim(params["imagen_url_manual"] || socket.assigns.form_imagen_url || "")
          {url, nil}

        {_, [_entry | _]} ->
          old_url = socket.assigns.form_imagen_url
          [{ext, content}] = consume_uploaded_entries(socket, :imagen, fn %{path: tmp_path}, e ->
            {:ok, {Path.extname(e.client_name), File.read!(tmp_path)}}
          end)
          # Guarda con URL anterior por ahora; la nueva se aplica en handle_continue
          {old_url, {codigo, ext, content, old_url}}

        {_, []} ->
          {socket.assigns.form_imagen_url, nil}
      end

    attrs = %{
      "codigo"          => codigo,
      "descripcion"     => String.trim(params["descripcion"] || ""),
      "desc_corta"      => String.trim(params["desc_corta"] || ""),
      "precio_base"     => parse_float(params["precio_base"]),
      "unidad"          => String.trim(params["unidad"] || "PZA"),
      "marca"           => String.trim(params["marca"] || ""),
      "notas"           => String.trim(params["notas"] || ""),
      "activo"          => socket.assigns.form_activo,
      "categoria"       => nilify(params["categoria"]),
      "super_categoria" => nilify(params["super_categoria"]),
      "imagen_url"      => nilify(imagen_url)
    }

    result =
      case socket.assigns.modal do
        :nuevo  -> ProductosNativos.crear(attrs)
        :editar -> ProductosNativos.actualizar(socket.assigns.selected, attrs)
      end

    case result do
      {:ok, _} ->
        msg = if socket.assigns.modal == :nuevo, do: "Producto creado", else: "Producto actualizado"
        sock = socket |> assign(:modal, nil) |> assign(:selected, nil) |> load_productos() |> put_flash(:info, msg)
        if pending_upload do
          {cod, ext, content, old_url} = pending_upload
          mime = case String.downcase(ext) do
            ".jpg"  -> "image/jpeg"
            ".jpeg" -> "image/jpeg"
            ".webp" -> "image/webp"
            ".gif"  -> "image/gif"
            _       -> "image/png"
          end
          data_url = "data:#{mime};base64,#{Base.encode64(content)}"
          previews = Map.put(sock.assigns.imagen_previews, cod, data_url)
          lv = self()
          Task.start(fn ->
            if old_url && old_url != "", do: Sftp.delete_by_url(old_url)
            case Sftp.upload_producto_nativo_image(cod, ext, content) do
              {:ok, url} -> send(lv, {:sftp_imagen_ok, cod, url <> "?v=#{System.os_time(:second)}"})
              {:error, r} -> send(lv, {:sftp_imagen_error, r})
            end
          end)
          {:noreply, sock |> assign(:imagen_previews, previews) |> assign(:subiendo_imagen, true)}
        else
          {:noreply, sock}
        end

      {:error, changeset} ->
        error = changeset.errors
          |> Enum.map(fn {k, {msg, _}} -> "#{k}: #{msg}" end)
          |> Enum.join(", ")
        {:noreply, assign(socket, :form_error, error)}
    end
  end

  @impl true
  def handle_info({:sftp_imagen_ok, codigo, url}, socket) do
    ProductosNativos.update_imagen(codigo, url)
    previews = Map.delete(socket.assigns.imagen_previews, codigo)
    {:noreply, socket |> assign(:subiendo_imagen, false) |> assign(:imagen_previews, previews) |> load_productos()}
  end

  def handle_info({:sftp_imagen_error, _reason}, socket) do
    {:noreply, socket |> assign(:subiendo_imagen, false) |> put_flash(:error, "No se pudo subir la imagen (error SFTP). El producto fue guardado sin imagen.")}
  end

  # ── Eliminar ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("eliminar", %{"codigo" => codigo}, socket) do
    case ProductosNativos.get(codigo) do
      nil -> {:noreply, socket}
      p ->
        if Prettycore.Pedidos.producto_en_pedido_activo?(codigo) do
          {:noreply, put_flash(socket, :error, "No se puede eliminar: el producto tiene pedidos pendientes o en proceso")}
        else
          if p.imagen_url && p.imagen_url != "" do
            Task.start(fn -> Sftp.delete_by_url(p.imagen_url) end)
          end
          ProductosNativos.eliminar(p)
          {:noreply, load_productos(socket)}
        end
    end
  end

  # ── Toggle activo rápido ─────────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_activo", %{"codigo" => codigo}, socket) do
    case ProductosNativos.get(codigo) do
      nil -> {:noreply, socket}
      p ->
        ProductosNativos.actualizar(p, %{"activo" => !p.activo})
        {:noreply, load_productos(socket)}
    end
  end

  @impl true
  def handle_event("validate_csv", _params, socket) do
    {:noreply, socket}
  end

  # ── Upload imagen ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("cambiar_imagen_modo", %{"modo" => modo}, socket) do
    {:noreply, assign(socket, imagen_modo: modo)}
  end

  @impl true
  def handle_event("validate_upload", params, socket) do
    socket =
      case {socket.assigns[:imagen_modo], Map.get(params, "imagen_url_manual")} do
        {"url", url} when is_binary(url) -> assign(socket, form_imagen_url: url)
        _ -> socket
      end
    {:noreply, socket}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp parse_float(nil), do: 0.0
  defp parse_float(""), do: 0.0
  defp parse_float(v) do
    case Float.parse(to_string(v)) do
      {f, _} -> f
      :error  -> 0.0
    end
  end


  defp nilify(nil), do: nil
  defp nilify(""), do: nil
  defp nilify(v), do: String.trim(v)

  # ── Template ──────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />
      <div class="flex-1 p-3 sm:p-6 min-w-0">
      <!-- Encabezado -->
      <div class="flex flex-wrap items-center justify-between gap-3 mb-6">
        <div class="min-w-0">
          <h1 class="text-xl font-bold text-gray-900">Productos Nativos</h1>
          <p class="text-sm text-gray-400 mt-0.5 hidden sm:block">
            Productos creados directamente en esta app — aparecen en la tienda junto con los de la API.
          </p>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <a
            href="/admin/productos-nativos/exportar"
            class="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-xl transition-colors"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
            </svg>
            Descargar
          </a>
          <button
            phx-click="abrir_importar"
            class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold rounded-xl transition-colors"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/>
            </svg>
            Importar
          </button>
          <button
            phx-click="nuevo"
            class="inline-flex items-center gap-2 px-4 py-2 bg-gray-900 hover:bg-black text-white text-sm font-semibold rounded-xl transition-colors"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
            </svg>
            Nuevo Producto
          </button>
        </div>
      </div>

      <!-- Buscador -->
      <div class="mb-4">
        <input
          type="text"
          phx-keyup="search"
          phx-debounce="300"
          name="q"
          value={@search}
          placeholder="Buscar por código o descripción…"
          class="w-full text-sm rounded-xl border border-gray-200 px-4 py-2.5 focus:outline-none focus:ring-2 focus:ring-gray-900"
        />
      </div>

      <!-- Tabla -->
      <%= if @productos == [] do %>
        <div class="text-center py-16 text-gray-400">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10" />
          </svg>
          <p class="text-sm font-medium">Sin productos nativos todavía</p>
          <p class="text-xs mt-1">Crea tu primer producto con el botón de arriba.</p>
        </div>
      <% else %>
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden overflow-x-auto">
          <table class="w-full text-sm min-w-[600px]">
            <thead class="bg-gray-50 border-b border-gray-100">
              <tr>
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Imagen</th>
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Código</th>
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Descripción</th>
                <th class="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Precio público</th>
                <th class="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Stock</th>
                <th class="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Activo</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <%= for p <- @productos do %>
                <tr class="hover:bg-gray-50 transition-colors">
                  <!-- Imagen -->
                  <td class="px-4 py-3">
                    <div class="w-10 h-10 rounded-lg overflow-hidden bg-gray-100 border border-gray-200 flex items-center justify-center">
                      <% img_src = Map.get(@imagen_previews, p.codigo) || p.imagen_url %>
                      <%= if img_src && img_src != "" do %>
                        <img src={img_src} class="w-full h-full object-cover" />
                      <% else %>
                        <svg class="w-5 h-5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      <% end %>
                    </div>
                  </td>
                  <!-- Código -->
                  <td class="px-4 py-3">
                    <span class="font-mono text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded"><%= p.codigo %></span>
                  </td>
                  <!-- Descripción -->
                  <td class="px-4 py-3">
                    <p class="font-medium text-gray-900 truncate max-w-xs"><%= p.descripcion %></p>
                    <%= if p.desc_corta && p.desc_corta != "" do %>
                      <p class="text-xs text-gray-400 mt-0.5"><%= p.desc_corta %></p>
                    <% end %>
                  </td>
                  <!-- Precio -->
                  <td class="px-4 py-3 text-right">
                    <span class="font-semibold text-green-600">$<%= :erlang.float_to_binary(p.precio_base / 1, decimals: 2) %></span>
                  </td>
                  <!-- Stock -->
                  <td class="px-4 py-3 text-center">
                    <%= if p.stock do %>
                      <span class={"text-xs font-semibold px-2 py-0.5 rounded-full " <> if p.stock > 0, do: "bg-emerald-100 text-emerald-700", else: "bg-red-100 text-red-600"}>
                        <%= p.stock %>
                      </span>
                    <% else %>
                      <span class="text-xs text-gray-300">—</span>
                    <% end %>
                  </td>
                  <!-- Activo -->
                  <td class="px-4 py-3 text-center">
                    <button
                      phx-click="toggle_activo"
                      phx-value-codigo={p.codigo}
                      class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors " <> if p.activo, do: "bg-emerald-500", else: "bg-gray-200"}
                    >
                      <span class={"inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform " <> if p.activo, do: "translate-x-6", else: "translate-x-1"} />
                    </button>
                  </td>
                  <!-- Acciones -->
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-1 justify-end">
                      <button
                        phx-click="editar"
                        phx-value-codigo={p.codigo}
                        class="p-1.5 text-gray-400 hover:text-gray-700 rounded-lg hover:bg-gray-100 transition-colors"
                        title="Editar"
                      >
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </button>
                      <button
                        phx-click="eliminar"
                        phx-value-codigo={p.codigo}
                        data-confirm={"¿Eliminar #{p.descripcion}?"}
                        class="p-1.5 text-gray-400 hover:text-red-500 rounded-lg hover:bg-red-50 transition-colors"
                        title="Eliminar"
                      >
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>

    <!-- ═══════════════════ MODAL IMPORTAR CSV ═══════════════════ -->
    <%= if @import_modal do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="cerrar_importar"></div>
        <div class="relative w-full max-w-md bg-white rounded-2xl shadow-2xl overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <div>
              <h2 class="text-base font-bold text-gray-900">Importar Productos</h2>
              <p class="text-xs text-gray-400 mt-0.5">Excel (.xlsx) o CSV</p>
            </div>
            <button phx-click="cerrar_importar" class="p-1.5 rounded-lg hover:bg-gray-100 text-gray-400 hover:text-gray-700 transition-colors">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>

          <div class="px-6 py-5 space-y-5">
            <!-- Paso 1: descargar plantilla -->
            <div class="bg-blue-50 border border-blue-200 rounded-xl p-4">
              <p class="text-xs font-semibold text-blue-700 uppercase tracking-wide mb-2">Paso 1 — Descargar plantilla</p>
              <p class="text-xs text-blue-600 mb-3">Descarga la plantilla, rellénala en Excel y súbela directamente como .xlsx (o guárdala como CSV separado por punto y coma).</p>
              <a href="/admin/productos-nativos/plantilla" target="_blank"
                class="inline-flex items-center gap-2 px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold rounded-lg transition-colors">
                <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
                Descargar plantilla .xlsx
              </a>
            </div>

            <!-- Paso 2: subir CSV -->
            <div>
              <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Paso 2 — Subir archivo Excel o CSV</p>
              <form phx-submit="importar_csv" phx-change="validate_csv">
                <div class="flex flex-col gap-3">
                  <label class={["flex flex-col items-center justify-center gap-2 w-full border-2 border-dashed rounded-xl py-6 cursor-pointer transition-colors",
                    if(Enum.any?(@uploads.csv_importar.entries), do: "border-emerald-400 bg-emerald-50", else: "border-gray-300 bg-gray-50 hover:border-gray-400")]}>
                    <svg class="w-8 h-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                    <%= if Enum.any?(@uploads.csv_importar.entries) do %>
                      <span class="text-sm font-semibold text-emerald-700"><%= hd(@uploads.csv_importar.entries).client_name %></span>
                    <% else %>
                      <span class="text-sm text-gray-500">Haz clic o arrastra tu archivo <span class="font-semibold">.xlsx</span> o <span class="font-semibold">.csv</span></span>
                    <% end %>
                    <.live_file_input upload={@uploads.csv_importar} class="hidden" />
                  </label>

                  <%= if @import_result do %>
                    <% prod = @import_result.productos %>
                    <%= if prod[:bloqueado] do %>
                      <div class="rounded-xl p-3 text-sm bg-red-50 border border-red-200">
                        <p class="font-semibold text-red-700 flex items-center gap-1.5">
                          <svg class="w-4 h-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
                          </svg>
                          Productos — campos obligatorios incompletos
                        </p>
                        <ul class="mt-2 text-xs text-red-600 space-y-0.5 max-h-28 overflow-y-auto">
                          <%= for e <- prod.errores do %><li>• <%= e %></li><% end %>
                        </ul>
                      </div>
                    <% else %>
                      <div class="rounded-xl border divide-y text-sm overflow-hidden">
                        <!-- Productos -->
                        <div class={"px-3 py-2 flex items-center justify-between " <> if prod.errores == [], do: "bg-green-50", else: "bg-amber-50"}>
                          <span class="font-semibold text-gray-700">📦 Productos</span>
                          <span class="text-xs text-gray-500">
                            <%= prod.nuevos %> nuevos · <%= prod.actualizados %> actualizados
                            <%= if prod.errores != [], do: " · #{length(prod.errores)} errores" %>
                          </span>
                        </div>
                        <!-- Stock -->
                        <%= if @import_result.stock do %>
                          <% stk = @import_result.stock %>
                          <div class={"px-3 py-2 flex items-center justify-between " <> if stk.errores == [], do: "bg-green-50", else: "bg-amber-50"}>
                            <span class="font-semibold text-gray-700">📊 Stock</span>
                            <span class="text-xs text-gray-500">
                              <%= stk.procesados %> registros
                              <%= if stk.errores != [], do: " · #{length(stk.errores)} errores" %>
                            </span>
                          </div>
                        <% end %>
                        <!-- Precios -->
                        <%= if @import_result.precios do %>
                          <% pre = @import_result.precios %>
                          <div class={"px-3 py-2 flex items-center justify-between " <> if pre.errores == [], do: "bg-green-50", else: "bg-amber-50"}>
                            <span class="font-semibold text-gray-700">💰 Precios</span>
                            <span class="text-xs text-gray-500">
                              <%= pre.procesados %> registros
                              <%= if pre.errores != [], do: " · #{length(pre.errores)} errores" %>
                            </span>
                          </div>
                        <% end %>
                        <!-- Sucursales -->
                        <%= if @import_result.sucursales do %>
                          <% suc = @import_result.sucursales %>
                          <div class={"px-3 py-2 flex items-center justify-between " <> if suc.errores == [], do: "bg-green-50", else: "bg-amber-50"}>
                            <span class="font-semibold text-gray-700">🏪 Sucursales</span>
                            <span class="text-xs text-gray-500">
                              <%= suc.procesados %> registros
                              <%= if suc.errores != [], do: " · #{length(suc.errores)} errores" %>
                            </span>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  <% end %>

                  <button type="submit"
                    disabled={Enum.empty?(@uploads.csv_importar.entries)}
                    class="w-full py-2.5 bg-emerald-600 hover:bg-emerald-700 disabled:bg-gray-200 disabled:cursor-not-allowed text-white disabled:text-gray-400 text-sm font-semibold rounded-xl transition-colors">
                    Importar
                  </button>
                </div>
              </form>
            </div>

            <!-- Referencia de columnas -->
            <details class="text-xs text-gray-400">
              <summary class="cursor-pointer hover:text-gray-600 font-medium">Ver columnas esperadas</summary>
              <div class="mt-2 font-mono bg-gray-50 rounded-lg p-2 text-[11px] leading-5 space-y-0.5">
                <p><span class="text-red-500">CODIGO*</span> · <span class="text-red-500">PRECIO*</span> · DESCRIPCION_LARGA</p>
                <p>NOMBRE · UNIDAD · MARCA</p>
                <p>CATEGORIA · SUPER_CATEGORIA · NOTAS · IMAGEN_URL</p>
              </div>
            </details>
          </div>
        </div>
      </div>
    <% end %>

    <!-- ═══════════════════ MODAL CREAR / EDITAR ═══════════════════ -->
    <%= if @modal in [:nuevo, :editar] do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="cerrar_modal"></div>
        <div class="relative w-full max-w-lg bg-white rounded-2xl shadow-2xl overflow-hidden">

          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <h2 class="text-base font-semibold text-gray-900">
              <%= if @modal == :nuevo, do: "Nuevo Producto", else: "Editar Producto" %>
            </h2>
            <button phx-click="cerrar_modal" class="p-1.5 text-gray-400 hover:text-gray-700 rounded-lg">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Error -->
          <%= if @form_error do %>
            <div class="mx-6 mt-4 p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl">
              <%= @form_error %>
            </div>
          <% end %>

          <!-- Form -->
          <form phx-submit="guardar" phx-change="validate_upload" class="px-6 py-5 space-y-4 overflow-y-auto max-h-[82vh]">

            <!-- Imagen (siempre arriba) -->
            <div>
              <!-- Tabs archivo / URL -->
              <div class="flex gap-0.5 mb-2 bg-gray-100 rounded-lg p-0.5 w-fit">
                <button type="button" phx-click="cambiar_imagen_modo" phx-value-modo="archivo"
                  class={["text-xs font-medium px-3 py-1.5 rounded-md transition-colors",
                           if(@imagen_modo == "archivo", do: "bg-white text-gray-800 shadow-sm", else: "text-gray-500 hover:text-gray-700")]}>
                  Subir archivo
                </button>
                <button type="button" phx-click="cambiar_imagen_modo" phx-value-modo="url"
                  class={["text-xs font-medium px-3 py-1.5 rounded-md transition-colors",
                           if(@imagen_modo == "url", do: "bg-white text-gray-800 shadow-sm", else: "text-gray-500 hover:text-gray-700")]}>
                  URL de imagen
                </button>
              </div>

              <%= if @imagen_modo == "archivo" do %>
                <!-- Subir archivo -->
                <div class="relative w-full h-44 rounded-2xl overflow-hidden">
                  <.live_file_input upload={@uploads.imagen}
                    id="img-input-producto-nativo"
                    phx-hook="ImageCompressor"
                    class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10" />

                  <%= cond do %>
                    <% @uploads.imagen.entries != [] -> %>
                      <% entry = List.first(@uploads.imagen.entries) %>
                      <div class="w-full h-full rounded-2xl overflow-hidden relative pointer-events-none">
                        <.live_img_preview entry={entry} class="w-full h-full object-cover" />
                        <div class="absolute bottom-0 left-0 right-0 bg-black/40 px-3 py-1.5 flex items-center gap-2">
                          <svg class="w-3.5 h-3.5 text-green-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
                          </svg>
                          <span class="text-[10px] text-white truncate"><%= entry.client_name %></span>
                        </div>
                      </div>

                    <% @form_imagen_url && @form_imagen_url != "" -> %>
                      <img src={@form_imagen_url} class="w-full h-full object-cover pointer-events-none" />
                      <div class="absolute inset-0 bg-black/20 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity pointer-events-none">
                        <div class="w-10 h-10 bg-white/90 rounded-full flex items-center justify-center">
                          <svg class="w-5 h-5 text-gray-800" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                          </svg>
                        </div>
                      </div>

                    <% true -> %>
                      <div class="w-full h-full border-2 border-dashed border-gray-300 rounded-2xl flex flex-col items-center justify-center gap-2 pointer-events-none">
                        <div class="relative">
                          <svg class="w-12 h-12 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                          </svg>
                          <div class="absolute -top-1 -right-1 w-6 h-6 bg-gray-900 rounded-full flex items-center justify-center">
                            <span class="text-white text-sm font-bold leading-none">+</span>
                          </div>
                        </div>
                        <span class="text-xs text-gray-400">Clic para agregar imagen</span>
                      </div>
                  <% end %>
                </div>
              <% else %>
                <!-- URL de imagen -->
                <div class="space-y-2">
                  <input
                    type="text"
                    name="imagen_url_manual"
                    value={@form_imagen_url}
                    placeholder="https://ejemplo.com/imagen.jpg"
                    phx-debounce="400"
                    class="w-full text-sm rounded-lg border border-gray-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-violet-400 focus:border-transparent"
                  />
                  <%= if @form_imagen_url && @form_imagen_url != "" do %>
                    <div class="relative w-full h-44 rounded-2xl overflow-hidden border border-gray-200">
                      <img src={@form_imagen_url} class="w-full h-full object-cover" />
                    </div>
                  <% else %>
                    <div class="w-full h-44 rounded-2xl border-2 border-dashed border-gray-200 flex flex-col items-center justify-center gap-1.5 text-gray-400">
                      <svg class="w-8 h-8 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
                      </svg>
                      <span class="text-xs">Pega la URL arriba para ver la vista previa</span>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <p class="text-[11px] text-gray-400 mt-1.5">Tamaño recomendado: 500 × 500 px</p>
              <%= if @upload_error do %>
                <p class="text-xs text-red-500 mt-1"><%= @upload_error %></p>
              <% end %>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                  Código *
                </label>
                <input
                  type="text"
                  name="codigo"
                  value={@form_codigo}
                  readonly
                  class="w-full text-sm rounded-lg border px-3 py-2 bg-gray-50 border-gray-200 text-gray-500 focus:outline-none"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                  Precio Público *
                </label>
                <input
                  type="number"
                  name="precio_base"
                  value={@form_precio}
                  step="0.01"
                  min="0.01"
                  max="999999.99"
                  required
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                />
              </div>
            </div>

            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide">
                  Descripción Larga *
                </label>
                <span id="desc_larga_count" class="text-xs text-gray-400"><%= String.length(@form_descripcion) %>/200</span>
              </div>
              <textarea
                name="descripcion"
                rows="2"
                required
                maxlength="200"
                placeholder="Nombre / descripción completa del producto"
                oninput="document.getElementById('desc_larga_count').textContent = this.value.length + '/200'"
                class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 resize-none"
              ><%= @form_descripcion %></textarea>
            </div>

            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide">
                  Nombre del Producto
                </label>
                <span id="desc_corta_count" class="text-xs text-gray-400"><%= String.length(@form_desc_corta) %>/40</span>
              </div>
              <input
                type="text"
                name="desc_corta"
                value={@form_desc_corta}
                placeholder="Nombre del producto"
                maxlength="40"
                oninput="document.getElementById('desc_corta_count').textContent = this.value.length + '/40'"
                class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
              />
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Unidad</label>
                <input
                  type="text"
                  name="unidad"
                  value={@form_unidad}
                  placeholder="PZA"
                  maxlength="20"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Marca</label>
                <input
                  type="text"
                  name="marca"
                  value={@form_marca}
                  placeholder="Opcional"
                  maxlength="100"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                />
              </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Categoría</label>
                <select name="categoria"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 bg-white">
                  <option value="">— Sin categoría —</option>
                  <%= for c <- @categorias_list do %>
                    <option value={c} selected={c == @form_categoria}><%= c %></option>
                  <% end %>
                </select>
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Super Categoría</label>
                <select name="super_categoria"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 bg-white">
                  <option value="">— Sin super categoría —</option>
                  <%= for sc <- @super_categorias_list do %>
                    <option value={sc} selected={sc == @form_super_categoria}><%= sc %></option>
                  <% end %>
                </select>
              </div>
            </div>

            <div>
              <div class="flex items-center justify-between mb-1">
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide">Notas</label>
                <span id="notas_count" class="text-xs text-gray-400"><%= String.length(@form_notas) %>/40</span>
              </div>
              <textarea
                name="notas"
                rows="2"
                placeholder="Observaciones internas (no se muestran al cliente)"
                maxlength="40"
                oninput="document.getElementById('notas_count').textContent = this.value.length + '/40'"
                class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 resize-none"
              ><%= @form_notas %></textarea>
            </div>

            <!-- Activo toggle -->
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-700">Visible en tienda</p>
                <p class="text-xs text-gray-400">Si está activo, se muestra en el catálogo.</p>
              </div>
              <button
                type="button"
                phx-click="toggle_activo_form"
                class={"relative inline-flex h-7 w-14 items-center rounded-full transition-colors " <> if @form_activo, do: "bg-emerald-500", else: "bg-gray-200"}
              >
                <span class={"inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform " <> if @form_activo, do: "translate-x-8", else: "translate-x-1"} />
                <span class={"absolute text-[10px] font-bold select-none " <> if @form_activo, do: "left-1.5 text-white", else: "right-1.5 text-gray-500"}>
                  <%= if @form_activo, do: "SÍ", else: "NO" %>
                </span>
              </button>
            </div>

            <!-- Footer botones -->
            <div class="flex justify-end gap-3 pt-2 border-t border-gray-100">
              <button
                type="button"
                phx-click="cerrar_modal"
                class="px-5 py-2 text-sm font-semibold text-gray-700 bg-white border border-gray-300 rounded-xl hover:bg-gray-50 transition-colors"
              >
                Cancelar
              </button>
              <button
                type="submit"
                phx-disable-with="Guardando..."
                class="px-5 py-2 text-sm font-semibold text-white bg-gray-900 hover:bg-black rounded-xl transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
              >
                <%= if @modal == :nuevo, do: "Crear Producto", else: "Guardar Cambios" %>
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>
    </div>
    """
  end
end
