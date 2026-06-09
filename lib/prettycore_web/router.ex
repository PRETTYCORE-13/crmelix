# lib/prettycore_web/router.ex
defmodule PrettycoreWeb.Router do
  use PrettycoreWeb, :router

  ## Pipelines
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug PrettycoreWeb.Plugs.TrackSession
    plug :fetch_live_flash
    plug :put_root_layout, {PrettycoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json"]
    plug PrettycoreWeb.Plugs.ApiAuth
  end

  ## Rutas de login y sesión
  scope "/", PrettycoreWeb do
    pipe_through :browser

    # Página de login (LiveView)
    live "/", LoginLive

    live "/restablecer/:token", ResetPasswordClienteLive
    live "/password-reset", PasswordResetLive

    # Controlador que valida usuario y crea sesión
    post "/", SessionController, :create

    # Logout (destruye sesión)
    get "/logout", SessionController, :delete
  end

  ## ÁREA PROTEGIDA: requiere sesión
  live_session :auth,
    on_mount: [{PrettycoreWeb.AuthOnMount, :ensure_authenticated}] do
    scope "/admin", PrettycoreWeb do
      pipe_through :browser

      live "/platform", Inicio
  #    live "/programacion", Programacion
  #    live "/programacion/sql", HerramientaSql
  #    live "/workorder", WorkOrderLive
      live "/tienda", Tienda
      live "/pedidos", PedidosLive
      live "/categorias", CategoriasLive
      live "/carrusel", CarruselLive
      live "/super-categorias", SuperCategoriasLive
      live "/secciones", SeccionesLive
      live "/seccion/:tipo", SeccionEditorLive
      live "/productos-nativos", ProductosNativosLive
      live "/clientes-nativos", ClientesNativosLive
      live "/listas-precios", ListasPreciosLive
      live "/gamas", GamasLive
      live "/sucursales", SucursalesLive
      live "/stock", StockLive
      live "/categorias-nativas", CategoriasNativasLive
      live "/configuracion", ConfiguracionLive
      live "/usuarios", Users.UsersCreateLive
    end
  end

  ## ÁREA SYSADMIN: interfaz separada, sin APIs externas
  live_session :sysadmin,
    on_mount: [{PrettycoreWeb.SysAdminAuthOnMount, :ensure_sysadmin}] do
    scope "/sysadmin", PrettycoreWeb.SysAdmin do
      pipe_through :browser

      live "/", ConfiguracionLive
      live "/configuracion", ConfiguracionLive
      live "/sesiones", SesionesLive
      live "/intelligence", ClientIntelligenceLive
      live "/usuarios", UsuariosLive
    end

    scope "/sysadmin", PrettycoreWeb do
      pipe_through :browser

      live "/tienda", Tienda
    end
  end

  ## Rutas para descarga de Excel (protegidas pero no LiveView)
  scope "/admin", PrettycoreWeb do
    pipe_through :browser

    get "/productos-nativos/plantilla", ProductosNativosTemplateController, :download
    get "/productos-nativos/exportar", ProductosNativosTemplateController, :exportar
  end

  ## Herramientas sysadmin (descargas, no LiveView)
  scope "/sysadmin", PrettycoreWeb do
    pipe_through :browser

    get "/architecture-scan", ArchitectureExcelController, :download
  end

  ## Health simple (sin login)
  scope "/", PrettycoreWeb do
    pipe_through :api
    get "/health", HealthController, :index
  end

  ## Endpoints JSON API
  scope "/api", PrettycoreWeb do
    pipe_through :api

    get "/sys_udn", SysUdnController, :index
    get "/sys_udn/codigos", SysUdnController, :codigos
  end

  ## API Productos — autenticación pública (obtener token)
  scope "/producto/point", PrettycoreWeb do
    pipe_through :api

    post "/token", ProductoPointController, :token
  end

  ## API Productos — requieren Bearer token
  scope "/producto/point", PrettycoreWeb do
    pipe_through :api_auth

    get  "/lista",         ListaProductoPointController, :index
    get  "/pty/:tabla",          PtyController, :index
    get  "/pty/:tabla/:id",      PtyController, :show
    post "/pty/buscar",          PtyController, :buscar
    get  "/sku",     ProductoPointController, :sku
    post "/sku",     ProductoPointController, :upsert_sku
    get  "/descrip", ProductoPointController, :descrip
    post "/descrip", ProductoPointController, :upsert_descrip
  end

  import Phoenix.LiveDashboard.Router

  scope "/dev" do
    pipe_through :browser

    live_dashboard "/dashboard", metrics: EecWeb.Telemetry
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end
end
