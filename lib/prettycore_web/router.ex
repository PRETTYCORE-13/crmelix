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

  ## Login y sesión
  scope "/", PrettycoreWeb do
    pipe_through :browser

    live "/"               , LoginLive
    live "/password-reset" , PasswordResetLive
    post "/"               , SessionController, :create
    get  "/logout"         , SessionController, :delete
  end

  ## Área protegida
  live_session :auth,
    on_mount: [{PrettycoreWeb.AuthOnMount, :ensure_authenticated}] do
    scope "/admin", PrettycoreWeb do
      pipe_through :browser

      live "/platform",  Inicio
      live "/productos", ProductosLive
    end
  end

  ## Sysadmin
  live_session :sysadmin,
    on_mount: [{PrettycoreWeb.SysAdminAuthOnMount, :ensure_sysadmin}] do
    scope "/sysadmin", PrettycoreWeb.SysAdmin do
      pipe_through :browser

      live "/"              , ConfiguracionLive
      live "/configuracion" , ConfiguracionLive
      live "/sesiones"      , SesionesLive
      live "/usuarios"      , UsuariosLive
    end
  end

  scope "/sysadmin", PrettycoreWeb do
    pipe_through :browser
    get "/architecture-scan", ArchitectureExcelController, :download
  end

  scope "/", PrettycoreWeb do
    pipe_through :api
    get "/health", HealthController, :index
  end

  ## API Productos
  scope "/api", PrettycoreWeb do
    pipe_through :api

    get    "/productos",     ProductoController, :index
    post   "/productos",     ProductoController, :create
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
