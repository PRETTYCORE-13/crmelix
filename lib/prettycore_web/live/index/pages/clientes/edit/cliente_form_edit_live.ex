defmodule PrettycoreWeb.ClienteFormEditLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Clientes.Api, as: ClientesApi
  alias Prettycore.Clientes
  alias Prettycore.Catalogos
  alias Prettycore.ClientIntelligence

  # Esquema embedded para Dirección
  defmodule DireccionForm do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      # Denominación comercial (display only, viene de CTE_DIRECCION)
      field(:ctecli_dencomercia, :string)

      # Datos de identificación (obligatorios)
      field(:ctedir_codigo_k, :string)
      field(:ctedir_responsable, :string)
      field(:ctedir_telefono, :string)

      # Dirección física (obligatorios)
      field(:ctedir_calle, :string)
      field(:ctedir_callenumext, :string)
      field(:ctedir_callenumint, :string)
      field(:ctedir_colonia, :string)
      field(:ctedir_cp, :string)

      # Contacto
      field(:ctedir_celular, :string)
      field(:ctedir_mail, :string)

      # Ubicación geográfica (obligatorios)
      field(:mapedo_codigo_k, :integer)
      field(:mapmun_codigo_k, :integer)
      field(:maploc_codigo_k, :integer)
      field(:map_x, :string)
      field(:map_y, :string)

      # Rutas (varias obligatorias según tipo)
      field(:vtarut_codigo_k_pre, :string)
      field(:vtarut_codigo_k_ent, :string)
      field(:vtarut_codigo_k_cob, :string)
      field(:vtarut_codigo_k_aut, :string)
      field(:vtarut_codigo_k_simpre, :string)
      field(:vtarut_codigo_k_siment, :string)
      field(:vtarut_codigo_k_simcob, :string)
      field(:vtarut_codigo_k_simaut, :string)
      field(:vtarut_codigo_k_sup, :string)

      # Configuración y catálogos
      field(:ctepfr_codigo_k, :string)
      field(:cteclu_codigo_k, :string)
      field(:ctezni_codigo_k, :string)
      field(:ctecor_codigo_k, :string)
      field(:condim_codigo_k, :string)
      field(:ctepaq_codigo_k, :string)

      # Embarque
      field(:ctevie_codigo_k, :string)
      field(:ctesvi_codigo_k, :string)

      # SAT y CFDI 4.0
      field(:satcp_codigo_k, :string)
      field(:satcol_codigo_k, :string)
      field(:c_estado_k, :string)
      field(:c_municipio_k, :string)
      field(:c_localidad_k, :string)

      # Estrategia
      field(:cfgest_codigo_k, :string)

      # Flags (valores por defecto según spec)
      field(:ctedir_tipofis, :boolean, default: false)
      field(:ctedir_tipoent, :boolean, default: false)
      field(:ctedir_ivafrontera, :string, default: "G")
      field(:ctedir_secuencia, :integer, default: 0)
      field(:ctedir_secuenciaent, :integer, default: 0)
      field(:ctedir_reqgeo, :integer, default: 0)
      field(:ctedir_distancia, :decimal, default: Decimal.new("1.0000"))
      field(:ctedir_novalidavencimiento, :integer, default: 0)
      field(:ctedir_edocred, :integer, default: 0)
      field(:ctedir_diascredito, :integer, default: 0)
      field(:ctedir_limitecredi, :decimal, default: Decimal.new("0"))
      field(:ctedir_tipopago, :integer, default: 0)
      field(:ctedir_tipodefacr, :integer, default: 0)
      field(:s_maqedo, :integer, default: 0)
      field(:ctedir_creditoobs, :string, default: "0")
    end

    def changeset(direccion, attrs) do
      changeset =
        direccion
        |> cast(attrs, [
          # Denominación comercial
          :ctecli_dencomercia,
          # Identificación
          :ctedir_codigo_k,
          :ctedir_responsable,
          :ctedir_telefono,
          # Dirección física
          :ctedir_calle,
          :ctedir_callenumext,
          :ctedir_callenumint,
          :ctedir_colonia,
          :ctedir_cp,
          # Contacto
          :ctedir_celular,
          :ctedir_mail,
          # Ubicación geográfica
          :mapedo_codigo_k,
          :mapmun_codigo_k,
          :maploc_codigo_k,
          :map_x,
          :map_y,
          # Rutas
          :vtarut_codigo_k_pre,
          :vtarut_codigo_k_ent,
          :vtarut_codigo_k_cob,
          :vtarut_codigo_k_aut,
          :vtarut_codigo_k_simpre,
          :vtarut_codigo_k_siment,
          :vtarut_codigo_k_simcob,
          :vtarut_codigo_k_simaut,
          :vtarut_codigo_k_sup,
          # Configuración y catálogos
          :ctepfr_codigo_k,
          :cteclu_codigo_k,
          :ctezni_codigo_k,
          :ctecor_codigo_k,
          :condim_codigo_k,
          :ctepaq_codigo_k,
          # Embarque
          :ctevie_codigo_k,
          :ctesvi_codigo_k,
          # SAT y CFDI 4.0
          :satcp_codigo_k,
          :satcol_codigo_k,
          :c_estado_k,
          :c_municipio_k,
          :c_localidad_k,
          # Estrategia
          :cfgest_codigo_k,
          # Flags
          :ctedir_tipofis,
          :ctedir_tipoent,
          :ctedir_ivafrontera,
          :ctedir_secuencia,
          :ctedir_secuenciaent,
          :ctedir_reqgeo,
          :ctedir_distancia,
          :ctedir_novalidavencimiento,
          :ctedir_edocred,
          :ctedir_diascredito,
          :ctedir_limitecredi,
          :ctedir_tipopago,
          :ctedir_tipodefacr,
          :s_maqedo,
          :ctedir_creditoobs
        ])

      # Solo validar si la dirección tiene al menos un campo lleno (no está completamente vacía)
      if direccion_tiene_datos?(changeset) do
        changeset
        |> validate_required(
          [
            # Campos obligatorios NOT NULL de CTE_DIRECCION
            :ctedir_codigo_k,
            :ctedir_calle,
            :ctedir_callenumext,
            :ctedir_cp,
            :mapedo_codigo_k,
            :mapmun_codigo_k,
            :maploc_codigo_k
          ],
          message: "Este campo es obligatorio"
        )
        |> validate_length(:ctedir_cp, min: 5, max: 5, message: "El CP debe tener 5 dígitos")
        |> validate_format(:ctedir_cp, ~r/^\d{5}$/, message: "El CP debe contener solo números")
        |> validate_rutas()
      else
        changeset
      end
    end

    # Validar que tenga al menos una ruta (preventa o autoventa/entrega)
    defp validate_rutas(changeset) do
      ruta_pre = get_field(changeset, :vtarut_codigo_k_pre)
      ruta_ent = get_field(changeset, :vtarut_codigo_k_ent)

      if is_nil_or_empty?(ruta_pre) and is_nil_or_empty?(ruta_ent) do
        add_error(changeset, :vtarut_codigo_k_pre, "Debe seleccionar ruta de preventa o entrega")
      else
        changeset
      end
    end

    defp is_nil_or_empty?(nil), do: true
    defp is_nil_or_empty?(""), do: true
    defp is_nil_or_empty?(_), do: false

    defp direccion_tiene_datos?(changeset) do
      # Verificar si alguno de los campos clave tiene valor
      campos_clave = [:ctedir_calle, :ctedir_callenumext, :ctedir_cp, :ctedir_codigo_k]

      Enum.any?(campos_clave, fn campo ->
        valor = get_change(changeset, campo) || get_field(changeset, campo)
        valor != nil && valor != ""
      end)
    end
  end

  # Esquema embedded para Cliente
  defmodule ClienteForm do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      # Identificación (requeridos)
      field(:ctecli_codigo_k, :string)
      field(:ctecli_razonsocial, :string)
      field(:ctecli_dencomercia, :string)
      field(:ctecli_rfc, :string, default: "XAXX010101000")

      # Fechas (requerido)
      field(:ctecli_fechaalta, :date)

      # Crédito
      field(:ctecli_edocred, :integer, default: 0)
      field(:ctecli_diascredito, :integer, default: 0)
      field(:ctecli_limitecredi, :decimal, default: Decimal.new("0.0000"))

      # Facturación
      field(:ctecli_tipodefact, :string)
      field(:ctecli_tipofacdes, :string)
      field(:ctecli_tipodefacr, :boolean, default: false)
      field(:ctecli_formapago, :string)
      field(:ctecli_metodopago, :string)
      field(:ctecli_tipopago, :string, default: "99")
      field(:sat_uso_cfdi_k, :string, default: "G01")
      field(:ctecli_fereceptormail, :string)

      # Catálogos obligatorios (NOT NULL)
      field(:ctetpo_codigo_k, :string)
      field(:ctecan_codigo_k, :string)
      field(:ctesca_codigo_k, :string)
      field(:ctereg_codigo_k, :string)

      # Catálogos opcionales con foreign keys
      field(:ctepaq_codigo_k, :string)
      field(:facadd_codigo_k, :string)
      field(:ctepor_codigo_k, :string)
      field(:condim_codigo_k, :string)
      field(:ctecad_codigo_k, :string)
      field(:cfgban_codigo_k, :string)
      field(:sysemp_codigo_k, :string)
      field(:faccom_codigo_k, :string)
      field(:facads_codigo_k, :string)
      field(:cteseg_codigo_k, :string)
      field(:cfgmon_codigo_k, :string)
      field(:catind_codigo_k, :string)
      field(:catpfi_codigo_k, :string)

      # Configuración regional
      field(:ctecli_pais, :string, default: "MEX")
      field(:cfgreg_codigo_k, :string, default: "601")
      field(:satexp_codigo_k, :string, default: "01")

      # Flags (valores por defecto según spec)
      field(:ctecli_generico, :integer, default: 0)
      field(:ctecli_nocta, :string)
      field(:ctecli_dscantimp, :boolean, default: true)
      field(:ctecli_desglosaieps, :boolean, default: false)
      field(:ctecli_periodorefac, :integer, default: 0)
      field(:ctecli_cargaespecifica, :integer, default: 0)
      field(:ctecli_caducidadmin, :integer, default: 0)
      field(:ctecli_ctlsanitario, :integer, default: 0)
      field(:ctecli_factablero, :integer, default: 0)
      field(:ctecli_aplicacanje, :integer, default: 0)
      field(:ctecli_aplicadev, :integer, default: 0)
      field(:ctecli_desglosakit, :boolean, default: false)
      field(:ctecli_facgrupo, :integer, default: 0)
      field(:ctecli_timbracb, :integer, default: 0)
      field(:ctecli_novalidavencimiento, :integer, default: 0)
      field(:ctecli_cfdi_ver, :string)
      field(:ctecli_aplicaregalo, :integer, default: 0)
      field(:ctecli_noaceptafracciones, :integer, default: 0)
      field(:ctecli_cxcliq, :integer, default: 0)

      # Campos adicionales de InfoCliente
      field(:ctecli_compatibilidad, :string)
      field(:ctecli_nombre, :string)
      field(:ctecli_prvporteofac, :string)
      field(:ctecli_ecommerce, :string)
      field(:ctecli_contacto, :string)
      field(:ctecli_fereceptor, :string)
      field(:ctecli_complemento, :string)
      field(:ctecli_creditoobs, :string)
      field(:ctecli_regtrib, :string)
      field(:ctecli_observaciones, :string)

      # Sistema (valores automáticos)
      field(:s_maqedo, :integer, default: 0)

      # Direcciones embebidas (múltiples)
      embeds_many(:direcciones, DireccionForm)
    end

    def changeset(cliente, attrs) do
      cliente
      |> cast(attrs, [
        # Identificación
        :ctecli_codigo_k,
        :ctecli_razonsocial,
        :ctecli_dencomercia,
        :ctecli_rfc,
        # Fechas
        :ctecli_fechaalta,
        # Crédito
        :ctecli_edocred,
        :ctecli_diascredito,
        :ctecli_limitecredi,
        # Facturación
        :ctecli_tipodefact,
        :ctecli_tipofacdes,
        :ctecli_tipodefacr,
        :ctecli_formapago,
        :ctecli_metodopago,
        :ctecli_tipopago,
        :sat_uso_cfdi_k,
        :ctecli_fereceptormail,
        # Catálogos obligatorios
        :ctetpo_codigo_k,
        :ctecan_codigo_k,
        :ctesca_codigo_k,
        :ctereg_codigo_k,
        # Catálogos opcionales
        :ctepaq_codigo_k,
        :facadd_codigo_k,
        :ctepor_codigo_k,
        :condim_codigo_k,
        :ctecad_codigo_k,
        :cfgban_codigo_k,
        :sysemp_codigo_k,
        :faccom_codigo_k,
        :facads_codigo_k,
        :cteseg_codigo_k,
        :cfgmon_codigo_k,
        :catind_codigo_k,
        :catpfi_codigo_k,
        # Configuración regional
        :ctecli_pais,
        :cfgreg_codigo_k,
        :satexp_codigo_k,
        # Flags
        :ctecli_generico,
        :ctecli_nocta,
        :ctecli_dscantimp,
        :ctecli_desglosaieps,
        :ctecli_periodorefac,
        :ctecli_cargaespecifica,
        :ctecli_caducidadmin,
        :ctecli_ctlsanitario,
        :ctecli_factablero,
        :ctecli_aplicacanje,
        :ctecli_aplicadev,
        :ctecli_desglosakit,
        :ctecli_facgrupo,
        :ctecli_timbracb,
        :ctecli_novalidavencimiento,
        :ctecli_cfdi_ver,
        :ctecli_aplicaregalo,
        :ctecli_noaceptafracciones,
        :ctecli_cxcliq,
        :s_maqedo,
        # Campos adicionales InfoCliente
        :ctecli_compatibilidad,
        :ctecli_nombre,
        :ctecli_prvporteofac,
        :ctecli_ecommerce,
        :ctecli_contacto,
        :ctecli_fereceptor,
        :ctecli_complemento,
        :ctecli_creditoobs,
        :ctecli_regtrib,
        :ctecli_observaciones
      ])
      |> cast_embed(:direcciones, required: false)
      |> put_default_fechaalta()
      |> validate_required(
        [
          # Campos obligatorios NOT NULL - validar solo al guardar
          :ctecli_codigo_k
        ],
        message: "Este campo es obligatorio"
      )
      |> validate_direcciones()
      |> validate_length(:ctecli_rfc, min: 12, max: 13)
      |> validate_format(:ctecli_rfc, ~r/^[A-Z&Ñ]{3,4}\d{6}[A-Z0-9]{3}$/,
        message: "formato RFC inválido"
      )
    end

    defp put_default_fechaalta(changeset) do
      if is_nil(get_field(changeset, :ctecli_fechaalta)) do
        put_change(changeset, :ctecli_fechaalta, Date.utc_today())
      else
        changeset
      end
    end

    defp validate_direcciones(changeset) do
      direcciones = get_field(changeset, :direcciones, [])

      # Verificar que haya al menos una dirección válida
      if Enum.empty?(direcciones) do
        add_error(changeset, :direcciones, "Debe agregar al menos una dirección")
      else
        changeset
      end
    end
  end

  @impl true
  def mount(params, _session, socket) do
    # Modo edición: obtener cliente_id de los parámetros
    cliente_id = Map.get(params, "id")
    frog_token = socket.assigns[:frog_token]

    # Cargar cliente existente desde la BD
    {cliente, page_title, current_path} = case Clientes.get_cliente_by_codigo(cliente_id, frog_token) do
      {:ok, %{cliente: cliente_db, direcciones: direcciones_db}} ->
        # Convertir direcciones de la BD al formato del formulario
        # Traer TODOS los campos tal como están en la BD (sin valores por defecto)
        direcciones_form = Enum.map(direcciones_db, fn dir ->
          %DireccionForm{
            ctecli_dencomercia: dir.ctecli_dencomercia,
            ctedir_codigo_k: dir.ctedir_codigo_k,
            ctedir_responsable: dir.ctedir_responsable,
            ctedir_telefono: dir.ctedir_telefono,
            ctedir_calle: dir.ctedir_calle,
            ctedir_callenumext: dir.ctedir_callenumext,
            ctedir_callenumint: dir.ctedir_callenumint,
            ctedir_colonia: dir.ctedir_colonia,
            ctedir_cp: dir.ctedir_cp,
            ctedir_celular: dir.ctedir_celular,
            ctedir_mail: dir.ctedir_mail,
            mapedo_codigo_k: dir.mapedo_codigo_k,
            mapmun_codigo_k: dir.mapmun_codigo_k,
            maploc_codigo_k: dir.maploc_codigo_k,
            map_x: dir.map_x,
            map_y: dir.map_y,
            vtarut_codigo_k_pre: dir.vtarut_codigo_k_pre,
            vtarut_codigo_k_ent: dir.vtarut_codigo_k_ent,
            vtarut_codigo_k_cob: dir.vtarut_codigo_k_cob,
            vtarut_codigo_k_aut: dir.vtarut_codigo_k_aut,
            vtarut_codigo_k_simpre: dir.vtarut_codigo_k_simpre,
            vtarut_codigo_k_siment: dir.vtarut_codigo_k_siment,
            vtarut_codigo_k_simcob: dir.vtarut_codigo_k_simcob,
            vtarut_codigo_k_simaut: dir.vtarut_codigo_k_simaut,
            vtarut_codigo_k_sup: dir.vtarut_codigo_k_sup,
            ctepfr_codigo_k: dir.ctepfr_codigo_k,
            cteclu_codigo_k: dir.cteclu_codigo_k,
            ctezni_codigo_k: dir.ctezni_codigo_k,
            ctecor_codigo_k: dir.ctecor_codigo_k,
            condim_codigo_k: dir.condim_codigo_k,
            ctepaq_codigo_k: dir.ctepaq_codigo_k,
            ctevie_codigo_k: dir.ctevie_codigo_k,
            ctesvi_codigo_k: dir.ctesvi_codigo_k,
            satcp_codigo_k: dir.satcp_codigo_k,
            satcol_codigo_k: dir.satcol_codigo_k,
            c_estado_k: dir.c_estado_k,
            c_municipio_k: dir.c_municipio_k,
            c_localidad_k: dir.c_localidad_k,
            cfgest_codigo_k: dir.cfgest_codigo_k,
            ctedir_tipofis: dir.ctedir_tipofis == 1 || dir.ctedir_tipofis == "1" || dir.ctedir_tipofis == true,
            ctedir_tipoent: dir.ctedir_tipoent == 1 || dir.ctedir_tipoent == "1" || dir.ctedir_tipoent == true,
            ctedir_ivafrontera: convert_ivafrontera(dir.ctedir_ivafrontera),
            ctedir_secuencia: dir.ctedir_secuencia,
            ctedir_secuenciaent: dir.ctedir_secuenciaent,
            ctedir_reqgeo: dir.ctedir_reqgeo,
            ctedir_distancia: dir.ctedir_distancia,
            ctedir_novalidavencimiento: dir.ctedir_novalidavencimiento,
            ctedir_edocred: dir.ctedir_edocred,
            ctedir_diascredito: dir.ctedir_diascredito,
            ctedir_limitecredi: dir.ctedir_limitecredi,
            ctedir_tipopago: dir.ctedir_tipopago,
            ctedir_tipodefacr: dir.ctedir_tipodefacr,
            s_maqedo: dir.s_maqedo,
            ctedir_creditoobs: dir.ctedir_creditoobs
          }
        end)

        # Si no hay direcciones, crear una por defecto
        direcciones_form = if Enum.empty?(direcciones_form) do
          [%DireccionForm{ctedir_codigo_k: "1"}]
        else
          direcciones_form
        end

        # Convertir cliente de BD al formato del formulario
        # Traer TODOS los campos tal como están en la BD (sin valores por defecto)
        cliente = %ClienteForm{
          ctecli_codigo_k: cliente_db.ctecli_codigo_k,
          ctecli_razonsocial: cliente_db.ctecli_razonsocial,
          ctecli_dencomercia: cliente_db.ctecli_dencomercia,
          ctecli_rfc: cliente_db.ctecli_rfc,
          ctecli_fechaalta: parse_date_field(cliente_db.ctecli_fechaalta),
          ctecli_edocred: cliente_db.ctecli_edocred,
          ctecli_diascredito: cliente_db.ctecli_diascredito,
          ctecli_limitecredi: cliente_db.ctecli_limitecredi,
          ctecli_tipodefact: if(cliente_db.ctecli_tipodefact, do: to_string(cliente_db.ctecli_tipodefact), else: nil),
          ctecli_tipofacdes: if(cliente_db.ctecli_tipofacdes, do: to_string(cliente_db.ctecli_tipofacdes), else: nil),
          ctecli_tipodefacr: if(cliente_db.ctecli_tipodefacr, do: cliente_db.ctecli_tipodefacr == 1, else: false),
          ctecli_formapago: cliente_db.ctecli_formapago,
          ctecli_metodopago: cliente_db.ctecli_metodopago,
          ctecli_tipopago: cliente_db.ctecli_tipopago,
          sat_uso_cfdi_k: cliente_db.sat_uso_cfdi_k,
          ctecli_fereceptormail: cliente_db.ctecli_fereceptormail,
          ctetpo_codigo_k: if(cliente_db.ctetpo_codigo_k, do: to_string(cliente_db.ctetpo_codigo_k), else: nil),
          ctecan_codigo_k: cliente_db.ctecan_codigo_k,
          ctesca_codigo_k: cliente_db.ctesca_codigo_k,
          ctereg_codigo_k: cliente_db.ctereg_codigo_k,
          ctepaq_codigo_k: cliente_db.ctepaq_codigo_k,
          facadd_codigo_k: cliente_db.facadd_codigo_k,
          ctepor_codigo_k: cliente_db.ctepor_codigo_k,
          condim_codigo_k: cliente_db.condim_codigo_k,
          ctecad_codigo_k: cliente_db.ctecad_codigo_k,
          cfgban_codigo_k: cliente_db.cfgban_codigo_k,
          faccom_codigo_k: cliente_db.faccom_codigo_k,
          facads_codigo_k: cliente_db.facads_codigo_k,
          cteseg_codigo_k: Map.get(cliente_db, :cteseg_codigo_k),
          cfgmon_codigo_k: cliente_db.cfgmon_codigo_k,
          catind_codigo_k: Map.get(cliente_db, :catind_codigo_k),
          catpfi_codigo_k: Map.get(cliente_db, :catpfi_codigo_k),
          ctecli_pais: cliente_db.ctecli_pais,
          ctecli_generico: cliente_db.ctecli_generico,
          ctecli_nocta: cliente_db.ctecli_nocta,
          ctecli_dscantimp: if(cliente_db.ctecli_dscantimp, do: cliente_db.ctecli_dscantimp == 1, else: false),
          ctecli_desglosaieps: if(cliente_db.ctecli_desglosaieps, do: cliente_db.ctecli_desglosaieps == 1, else: false),
          ctecli_periodorefac: cliente_db.ctecli_periodorefac,
          ctecli_cargaespecifica: cliente_db.ctecli_cargaespecifica,
          ctecli_caducidadmin: cliente_db.ctecli_caducidadmin,
          ctecli_ctlsanitario: cliente_db.ctecli_ctlsanitario,
          ctecli_factablero: cliente_db.ctecli_factablero,
          ctecli_aplicacanje: cliente_db.ctecli_aplicacanje,
          ctecli_aplicadev: cliente_db.ctecli_aplicadev,
          ctecli_desglosakit: if(cliente_db.ctecli_desglosakit, do: cliente_db.ctecli_desglosakit == 1, else: false),
          ctecli_facgrupo: cliente_db.ctecli_facgrupo,
          ctecli_cxcliq: cliente_db.ctecli_cxcliq,
          s_maqedo: cliente_db.s_maqedo,
          ctecli_timbracb: cliente_db.ctecli_timbracb,
          sysemp_codigo_k: cliente_db.sysemp_codigo_k,
          ctecli_novalidavencimiento: cliente_db.ctecli_novalidavencimiento,
          ctecli_compatibilidad: Map.get(cliente_db, :ctecli_compatibilidad),
          satexp_codigo_k: cliente_db.satexp_codigo_k,
          cfgreg_codigo_k: cliente_db.cfgreg_codigo_k,
          ctecli_cfdi_ver: if(cliente_db.ctecli_cfdi_ver, do: to_string(cliente_db.ctecli_cfdi_ver), else: nil),
          ctecli_nombre: Map.get(cliente_db, :ctecli_nombre),
          ctecli_aplicaregalo: cliente_db.ctecli_aplicaregalo,
          ctecli_prvporteofac: Map.get(cliente_db, :ctecli_prvporteofac),
          ctecli_noaceptafracciones: cliente_db.ctecli_noaceptafracciones,
          ctecli_ecommerce: Map.get(cliente_db, :ctecli_ecommerce),
          ctecli_contacto: Map.get(cliente_db, :ctecli_contacto),
          ctecli_fereceptor: Map.get(cliente_db, :ctecli_fereceptor),
          ctecli_complemento: Map.get(cliente_db, :ctecli_complemento),
          ctecli_creditoobs: Map.get(cliente_db, :ctecli_creditoobs),
          ctecli_regtrib: Map.get(cliente_db, :ctecli_regtrib),
          ctecli_observaciones: Map.get(cliente_db, :ctecli_observaciones),
          direcciones: direcciones_form
        }

        {cliente, "Editar Cliente #{cliente_id}", "/admin/clientes/edit/#{cliente_id}"}

      {:error, :not_found} ->
        # Si no se encuentra el cliente, crear uno vacío con ese código
        cliente = %ClienteForm{
          ctecli_codigo_k: cliente_id,
          ctecli_fechaalta: Date.utc_today(),
          direcciones: [%DireccionForm{ctedir_codigo_k: "1"}]
        }
        {cliente, "Editar Cliente #{cliente_id} (No encontrado)", "/admin/clientes/edit/#{cliente_id}"}
    end

    form = to_form(ClienteForm.changeset(cliente, %{}))

    # Cargar catálogos desde la API (con token)
    t = frog_token
    tipos_cliente = Catalogos.listar_tipos_cliente(t)
    cadenas = Catalogos.listar_cadenas(t)
    canales = Catalogos.listar_canales(t)
    regimenes = Catalogos.listar_regimenes(t)
    paquetes_servicio = Catalogos.listar_paquetes_servicio(t)
#    transacciones = Catalogos.listar_transacciones(t)
    monedas = Catalogos.listar_monedas(t)
    estados = Catalogos.listar_estados(t)

    rutas = Catalogos.listar_rutas(t)
    usos_cfdi = Catalogos.listar_usos_cfdi(t)
    formas_pago = Catalogos.listar_formas_pago(t)
    metodos_pago = Catalogos.listar_metodos_pago(t)
    regimenes_fiscales = Catalogos.listar_regimenes_fiscales(t)

    # Cargar subcanales si el cliente tiene un canal seleccionado
    subcanales = if cliente.ctecan_codigo_k do
      Catalogos.listar_subcanales(cliente.ctecan_codigo_k, t)
      []
    else
      []
    end

    # Cargar municipios y localidades si la primera dirección tiene estado y municipio válidos
    {municipios, localidades} = if length(cliente.direcciones) > 0 do
      primera_dir = Enum.at(cliente.direcciones, 0)
      edo = primera_dir.mapedo_codigo_k
      mun = primera_dir.mapmun_codigo_k

      municipios = if edo && edo != 0 && edo != "0" do
        Catalogos.listar_municipios(edo, t)
      else
        []
      end

      localidades = if edo && edo != 0 && edo != "0" && mun && mun != 0 && mun != "0" do
        Catalogos.listar_localidades(edo, mun, t)
      else
        []
      end

      {municipios, localidades}
    else
      {[], []}
    end

    {:ok,
     socket
     |> assign(:current_page, "clientes")
     |> assign(:sidebar_open, true)
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
     |> assign(:current_path, current_path)
     |> assign(:form, form)
     |> assign(:page_title, page_title)
     |> assign(:current_tab, "basicos")
     |> assign(:cliente_id, cliente_id)
     |> assign(:tipos_cliente, tipos_cliente)
     |> assign(:cadenas, cadenas)
     |> assign(:canales, canales)
     |> assign(:subcanales, subcanales)
     |> assign(:regimenes, regimenes)
     |> assign(:paquetes_servicio, paquetes_servicio)
#     |> assign(:transacciones, transacciones)
     |> assign(:monedas, monedas)
     |> assign(:estados, estados)
     |> assign(:municipios, municipios)
     |> assign(:localidades, localidades)
     |> assign(:rutas, rutas)
     |> assign(:usos_cfdi, usos_cfdi)
     |> assign(:formas_pago, formas_pago)
     |> assign(:metodos_pago, metodos_pago)
     |> assign(:regimenes_fiscales, regimenes_fiscales)
     |> assign(:cfdi_tab, "cfdi_32")
     |> assign(:direccion_tab, "datos")
     |> assign(:open_direcciones, MapSet.new())
     |> assign(:complementos, [])
     |> assign(:paises, [{"México", "MEX"}])
     |> assign(:codigos_exportacion, [{"No aplica", "01"}, {"Definitiva", "02"}])
     |> assign(:show_json_modal, false)
     |> assign(:json_preview, nil)
     |> assign(:pending_changeset, nil)
     |> assign(:permitir_edicion, Prettycore.SysAdmin.get_config().permitir_edicion != false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Get tab from params, default to "basicos"
    tab = Map.get(params, "tab", "basicos")
    # Validate tab
    valid_tabs = ["basicos", "clasificacion", "facturacion", "direcciones", "opcionales"]
    current_tab = if tab in valid_tabs, do: tab, else: "basicos"

    {:noreply, assign(socket, :current_tab, current_tab)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"_target" => target, "cliente_form" => params} = _event_params,
        socket
      ) do
    changeset =
      %ClienteForm{}
      |> ClienteForm.changeset(params)
      |> Map.put(:action, :validate)

    # Check if the change was on a estado or municipio field
    socket_with_form = assign(socket, :form, to_form(changeset))

    case target do
      # Root level fields (formulario nuevo)
      ["cliente_form", "mapedo_codigo_k"] ->
        # Estado changed, load municipios
        estado_codigo = Map.get(params, "mapedo_codigo_k")
        IO.inspect(estado_codigo, label: "Estado seleccionado (validate)")
        IO.inspect(target, label: "Target path")

        tk = socket.assigns[:frog_token]
        if estado_codigo && estado_codigo != "" do
          municipios = Catalogos.listar_municipios(estado_codigo, tk)
          {:noreply, socket_with_form |> assign(:municipios, municipios) |> assign(:localidades, [])}
        else
          {:noreply, socket_with_form |> assign(:municipios, []) |> assign(:localidades, [])}
        end

      ["cliente_form", "mapmun_codigo_k"] ->
        # Municipio changed, load localidades
        estado_codigo = Map.get(params, "mapedo_codigo_k")
        municipio_codigo = Map.get(params, "mapmun_codigo_k")
        tk = socket.assigns[:frog_token]

        if estado_codigo && municipio_codigo && estado_codigo != "" && municipio_codigo != "" do
          localidades = Catalogos.listar_localidades(estado_codigo, municipio_codigo, tk)
          {:noreply, assign(socket_with_form, :localidades, localidades)}
        else
          {:noreply, assign(socket_with_form, :localidades, [])}
        end

      # Nested direcciones (para formularios con múltiples direcciones)
      ["cliente_form", "direcciones", direccion_index, "mapedo_codigo_k"] ->
        estado_codigo = get_in(params, ["direcciones", direccion_index, "mapedo_codigo_k"])
        tk = socket.assigns[:frog_token]

        if estado_codigo && estado_codigo != "" do
          municipios = Catalogos.listar_municipios(estado_codigo, tk)
          {:noreply, socket_with_form |> assign(:municipios, municipios) |> assign(:localidades, [])}
        else
          {:noreply, socket_with_form |> assign(:municipios, []) |> assign(:localidades, [])}
        end

      ["cliente_form", "direcciones", direccion_index, "mapmun_codigo_k"] ->
        estado_codigo = get_in(params, ["direcciones", direccion_index, "mapedo_codigo_k"])
        municipio_codigo = get_in(params, ["direcciones", direccion_index, "mapmun_codigo_k"])
        tk = socket.assigns[:frog_token]

        if estado_codigo && municipio_codigo && estado_codigo != "" && municipio_codigo != "" do
          localidades = Catalogos.listar_localidades(estado_codigo, municipio_codigo, tk)
          {:noreply, assign(socket_with_form, :localidades, localidades)}
        else
          {:noreply, assign(socket_with_form, :localidades, [])}
        end

      _ ->
        # Other field changed, just validate
        {:noreply, socket_with_form}
    end
  end

  # Fallback clause when _target is not present
  def handle_event("validate", %{"cliente_form" => params}, socket) do
    changeset =
      %ClienteForm{}
      |> ClienteForm.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"cliente_form" => params}, socket) do
    changeset = ClienteForm.changeset(%ClienteForm{}, params)

    case validate_and_extract(changeset) do
      {:ok, cliente_data} ->
        # Generar el JSON que se enviará y mostrarlo en modal de confirmación
        json_string = ClientesApi.build_json_string(cliente_data)
        json_pretty = case Jason.decode(json_string) do
          {:ok, decoded} -> Jason.encode!(decoded, pretty: true)
          _ -> json_string
        end

        {:noreply,
         socket
         |> assign(:show_json_modal, true)
         |> assign(:json_preview, json_pretty)
         |> assign(:pending_changeset, changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        missing_fields = extract_missing_fields(changeset)
        error_message = "Para continuar te hace falta: #{missing_fields}"
        changeset_with_action = Map.put(changeset, :action, :validate)
        {:noreply,
         socket
         |> put_flash(:error, error_message)
         |> assign(:form, to_form(changeset_with_action))}
    end
  end

  @impl true
  def handle_event("confirm_save", _params, socket) do
    changeset = socket.assigns.pending_changeset
    {:ok, cliente_data} = validate_and_extract(changeset)
    frog_token = socket.assigns[:frog_token]

    socket = assign(socket, show_json_modal: false, json_preview: nil, pending_changeset: nil)

    if is_nil(frog_token) do
      {:noreply,
       socket
       |> put_flash(:error, "Sesión no válida. Por favor inicie sesión nuevamente.")
       |> assign(:form, to_form(changeset))}
    else
      case ClientesApi.editar_cliente(cliente_data, frog_token) do
        {:ok, _response} ->
          Prettycore.Clientes.invalidar_cache()
          ClientIntelligence.track_event(
            cliente_data.ctecli_codigo_k,
            socket.assigns[:current_user_id],
            "edited"
          )

          {:noreply,
           socket
           |> put_flash(:info, "Cliente actualizado exitosamente")
           |> push_event("navigate-after-flash", %{to: "/admin/clientes", delay: 3000})}

        {:error, {:http_error, status, body}} ->
          error_msg = extract_error_message(body, status)

          {:noreply,
           socket
           |> put_flash(:error, "Error al actualizar cliente: #{error_msg}")
           |> assign(:form, to_form(changeset))}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error de conexión: #{inspect(reason)}")
           |> assign(:form, to_form(changeset))}
      end
    end
  end

  @impl true
  def handle_event("cancel_save", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_json_modal, false)
     |> assign(:json_preview, nil)
     |> assign(:pending_changeset, nil)}
  end

  @impl true
  def handle_event("add_direccion", _params, socket) do
    current_form = socket.assigns.form
    params = current_form.params || %{}

    # Obtener direcciones existentes (puede ser mapa o lista)
    direcciones_raw = Map.get(params, "direcciones", %{})

    direcciones_list =
      case direcciones_raw do
        dirs when is_map(dirs) -> Map.values(dirs)
        dirs when is_list(dirs) -> dirs
        _ -> []
      end

    next_index = length(direcciones_list) |> to_string()
    next_codigo = (length(direcciones_list) + 1) |> to_string()

    new_direccion = %{
      "ctedir_codigo_k" => next_codigo,
      "ctedir_calle" => "",
      "ctedir_callenumext" => "",
      "ctedir_cp" => "",
      "ctedir_tipofis" => "false",
      "ctedir_tipoent" => "false"
    }

    updated_direcciones =
      direcciones_list
      |> Enum.with_index()
      |> Enum.map(fn {dir, idx} -> {to_string(idx), dir} end)
      |> Map.new()
      |> Map.put(next_index, new_direccion)

    updated_params = Map.put(params, "direcciones", updated_direcciones)

    changeset =
      %ClienteForm{}
      |> ClienteForm.changeset(updated_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("remove_direccion", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_form = socket.assigns.form
    params = current_form.params || %{}

    # Obtener direcciones existentes (puede ser mapa o lista)
    direcciones_raw = Map.get(params, "direcciones", %{})

    direcciones_list =
      case direcciones_raw do
        dirs when is_map(dirs) -> Map.values(dirs)
        dirs when is_list(dirs) -> dirs
        _ -> []
      end

    if length(direcciones_list) <= 1 do
      {:noreply, put_flash(socket, :error, "Debe mantener al menos una dirección")}
    else
      updated_list = List.delete_at(direcciones_list, index)

      updated_direcciones =
        updated_list
        |> Enum.with_index()
        |> Enum.map(fn {dir, idx} -> {to_string(idx), dir} end)
        |> Map.new()

      updated_params = Map.put(params, "direcciones", updated_direcciones)

      changeset =
        %ClienteForm{}
        |> ClienteForm.changeset(updated_params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("canal_change", %{"_target" => _target, "cliente_form" => params}, socket) do
    # Get canal_codigo from params
    canal_codigo = get_in(params, ["ctecan_codigo_k"])

    if canal_codigo && canal_codigo != "" do
      subcanales = Catalogos.listar_subcanales(canal_codigo, socket.assigns[:frog_token])
      {:noreply, assign(socket, :subcanales, subcanales)}
    else
      {:noreply, assign(socket, :subcanales, [])}
    end
  end

  @impl true
  def handle_event("change_cfdi_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :cfdi_tab, tab)}
  end

  @impl true
  def handle_event("change_direccion_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :direccion_tab, tab)}
  end

  @impl true
  def handle_event("toggle_direccion", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    open = socket.assigns.open_direcciones

    updated =
      if MapSet.member?(open, index),
        do: MapSet.delete(open, index),
        else: MapSet.put(open, index)

    {:noreply, assign(socket, :open_direcciones, updated)}
  end

  @impl true
  def handle_event("update_coordinates", %{"lat" => lat, "lng" => lng, "index" => index_str}, socket) do
    # Este evento se llama desde el hook de JavaScript cuando se actualiza el mapa
    current_form = socket.assigns.form
    params = current_form.params || %{}
    direcciones = Map.get(params, "direcciones", %{})

    # Actualizar las coordenadas en la dirección correspondiente
    index = index_str
    direccion = Map.get(direcciones, index, %{})
    updated_direccion = Map.merge(direccion, %{"map_y" => to_string(lat), "map_x" => to_string(lng)})
    updated_direcciones = Map.put(direcciones, index, updated_direccion)
    updated_params = Map.put(params, "direcciones", updated_direcciones)

    changeset = ClienteForm.changeset(%ClienteForm{}, updated_params)
    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("update_coordinates", %{"lat" => _lat, "lng" => _lng}, socket) do
    # Fallback si no viene el index
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_map_from_coords", _params, socket) do
    # Este evento se llama cuando el usuario actualiza manualmente las coordenadas
    {:noreply, socket}
  end

  @impl true
  def handle_event("cp_blur", %{"codigo_postal" => cp, "direccion_index" => index_str}, socket) do
    if String.match?(cp, ~r/^\d{5}$/) do
      tk = socket.assigns[:frog_token]
      case Catalogos.buscar_por_cp(cp, tk) do
        {:ok, ubicacion} ->
          municipios = Catalogos.listar_municipios(ubicacion.estado_codigo, tk)

          localidades =
            Catalogos.listar_localidades(ubicacion.estado_codigo, ubicacion.municipio_codigo, tk)

          current_form = socket.assigns.form
          params = current_form.params || %{}
          direcciones = Map.get(params, "direcciones", [])
          index = String.to_integer(index_str)

          updated_direccion =
            Enum.at(direcciones, index)
            |> Map.put("mapedo_codigo_k", ubicacion.estado_codigo)
            |> Map.put("mapmun_codigo_k", ubicacion.municipio_codigo)
            |> Map.put("maploc_codigo_k", ubicacion.localidad_codigo)

          updated_direcciones = List.replace_at(direcciones, index, updated_direccion)
          updated_params = Map.put(params, "direcciones", updated_direcciones)

          changeset =
            %ClienteForm{}
            |> ClienteForm.changeset(updated_params)
            |> Map.put(:action, :validate)

          {:noreply,
           socket
           |> assign(:form, to_form(changeset))
           |> assign(:municipios, municipios)
           |> assign(:localidades, localidades)
           |> put_flash(
             :info,
             "Ubicación encontrada: #{ubicacion.estado_nombre}, #{ubicacion.municipio_nombre}"
           )}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "No se encontró ubicación para el CP: #{cp}")}

        {:error, :invalid_cp} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    cliente_id = socket.assigns[:cliente_id]
    {:noreply, push_patch(socket, to: ~p"/admin/clientes/edit/#{cliente_id}/#{tab}")}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket)
  end

  defp validate_and_extract(changeset) do
    if changeset.valid? do
      cliente = Ecto.Changeset.apply_changes(changeset)
      IO.inspect(cliente.direcciones, label: "Direcciones en validate_and_extract")
      {:ok, cliente}
    else
      {:error, changeset}
    end
  end

  defp extract_error_message(body, _status) when is_list(body) do
    case body do
      [error | _] when is_map(error) ->
        case Map.get(error, "Respuesta") do
          nil -> "Error del servidor"
          respuesta -> parse_api_error(respuesta)
        end
      _ -> "Error del servidor"
    end
  end

  defp extract_error_message(_body, status), do: "Error HTTP #{status}"

  # Parsea el mensaje de error de la API para mostrar solo la parte amigable
  defp parse_api_error(respuesta) when is_binary(respuesta) do
    cond do
      # Extraer mensaje después de PreConditionsException:
      String.contains?(respuesta, "PreConditionsException:") ->
        respuesta
        |> String.split("PreConditionsException:")
        |> List.last()
        |> String.split("\r\n")
        |> List.first()
        |> String.trim()

      # Extraer mensaje después de Exception:
      String.contains?(respuesta, "Exception:") ->
        respuesta
        |> String.split("Exception:")
        |> List.last()
        |> String.split("\r\n")
        |> List.first()
        |> String.trim()

      # Si no hay patrón conocido, tomar la primera línea
      true ->
        respuesta
        |> String.split("\r\n")
        |> List.first()
        |> String.trim()
    end
  end

  defp parse_api_error(_), do: "Error del servidor"

  # Convierte el valor de IVA frontera de la BD al formato del select
  # BD: 0 = General, 1 = Frontera | Select: "G" = General, "F" = Frontera
  defp convert_ivafrontera(0), do: "G"
  defp convert_ivafrontera("0"), do: "G"
  defp convert_ivafrontera(1), do: "F"
  defp convert_ivafrontera("1"), do: "F"
  defp convert_ivafrontera("G"), do: "G"
  defp convert_ivafrontera("F"), do: "F"
  defp convert_ivafrontera(_), do: "G"

  defp parse_date_field(nil), do: nil
  defp parse_date_field(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)
  defp parse_date_field(%Date{} = d), do: d
  defp parse_date_field(s) when is_binary(s) do
    case NaiveDateTime.from_iso8601(s) do
      {:ok, ndt} -> NaiveDateTime.to_date(ndt)
      _ ->
        case Date.from_iso8601(s) do
          {:ok, d} -> d
          _ -> nil
        end
    end
  end
  defp parse_date_field(_), do: nil

  # Extrae los nombres legibles de los campos faltantes del changeset
  defp extract_missing_fields(changeset) do
    field_names = %{
      ctecli_codigo_k: "Codigo de cliente",
      ctecli_razonsocial: "Razon social",
      ctecli_dencomercia: "Denominacion comercial",
      ctecli_rfc: "RFC",
      ctecli_fechaalta: "Fecha de alta",
      ctetpo_codigo_k: "Tipo de cliente",
      ctecan_codigo_k: "Canal",
      ctesca_codigo_k: "Subcanal",
      ctereg_codigo_k: "Regimen",
      ctepaq_codigo_k: "Paquete de servicio",
      ctecli_formapago: "Forma de pago",
      ctecli_metodopago: "Metodo de pago",
      sat_uso_cfdi_k: "Uso CFDI",
      cfgreg_codigo_k: "Regimen fiscal",
      direcciones: "Direcciones",
      ctedir_codigo_k: "Codigo de direccion",
      ctedir_calle: "Calle",
      ctedir_callenumext: "Numero exterior",
      ctedir_cp: "Codigo postal",
      mapedo_codigo_k: "Estado",
      mapmun_codigo_k: "Municipio",
      maploc_codigo_k: "Localidad",
      vtarut_codigo_k_pre: "Ruta de preventa o entrega",
      vtarut_codigo_k_ent: "Ruta de entrega"
    }

    # Errores del nivel principal
    main_errors = Enum.map(changeset.errors, fn {field, _} -> field end)

    # Errores de direcciones embebidas
    direcciones_errors =
      case Map.get(changeset.changes, :direcciones, []) do
        direcciones when is_list(direcciones) ->
          Enum.flat_map(direcciones, fn dir_changeset ->
            case dir_changeset do
              %Ecto.Changeset{errors: errors} ->
                Enum.map(errors, fn {field, _} -> field end)
              _ ->
                []
            end
          end)
        _ ->
          []
      end

    # Combinar todos los errores
    all_errors = main_errors ++ direcciones_errors

    all_errors
    |> Enum.map(fn field -> Map.get(field_names, field, Atom.to_string(field)) end)
    |> Enum.uniq()
    |> Enum.join(", ")
  end
end
