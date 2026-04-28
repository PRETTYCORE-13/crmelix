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

  ## Rutas de login y sesión
  scope "/", PrettycoreWeb do
    pipe_through :browser

    # Página de login (LiveView)
    live "/", LoginLive

    # Nueva ruta para cambio de contraseña (UI)
    live "/password-reset", PasswordResetLive

    # Controlador que valida usuario y crea sesión
    post "/", SessionController, :create

    # Logout (destruye sesión)
    get "/logout", SessionController, :delete
  end

  ## Pantalla de carga (sin AuthOnMount para no hacer API calls extra)
  live_session :loading do
    scope "/admin", PrettycoreWeb do
      pipe_through :browser
      live "/loading", LoadingLive
    end
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
      live "/clientes", Clientes
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
      live "/usuarios", Users.UsersCreateLive
      live "/clientes/new", ClienteFormNewLive
      live "/clientes/new/:tab", ClienteFormNewLive
      live "/clientes/edit/:id", ClienteFormEditLive
      live "/clientes/edit/:id/:tab", ClienteFormEditLive
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

    get "/clientes/export/excel", ClientesExcelController, :download
    get "/productos-nativos/plantilla", ProductosNativosTemplateController, :download
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

  import Phoenix.LiveDashboard.Router

  scope "/dev" do
    pipe_through :browser

    live_dashboard "/dashboard", metrics: EecWeb.Telemetry
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end
end
