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
      live "/usuarios", Users.UsersCreateLive
      live "/disenador", DisenadorLive
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
      live "/usuarios", UsuariosLive
    end

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

  ## API — obtener token (sin auth requerida)
  scope "/api", PrettycoreWeb do
    pipe_through :api
    post "/auth/token", DynController, :auth_token
  end

  ## API Dinámica — esquema definidos en el diseñador
  scope "/api/dyn", PrettycoreWeb do
    pipe_through :api_auth

    get    "/:modelo",          DynController, :index
    get    "/:modelo/:id",      DynController, :show
    post   "/:modelo",          DynController, :create
    put    "/:modelo/:id",      DynController, :update
    delete "/:modelo/:id",      DynController, :delete
    post   "/:modelo/buscar",   DynController, :buscar
  end

  if Mix.env() == :dev do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EecWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
