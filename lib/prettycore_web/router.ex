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

      live "/platform", Inicio
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

  scope "/api", PrettycoreWeb do
    pipe_through :api

    get  "/productos",     ProductoController, :index
    get  "/productos/:id", ProductoController, :buscar_id
    post "/productos",     ProductoController, :create
    put  "/productos/:id", ProductoController, :update

    get  "/clientes",     ClienteController, :index
    get  "/clientes/:id", ClienteController, :buscar_id
    post "/clientes",     ClienteController, :create
    put  "/clientes/:id", ClienteController, :update

    get  "/marcas",     MarcaController, :index
    get  "/marcas/:id", MarcaController, :buscar_id
    post "/marcas",     MarcaController, :create
    put  "/marcas/:id", MarcaController, :update

    get  "/supercategorias",     SupercategoriaController, :index
    get  "/supercategorias/:id", SupercategoriaController, :buscar_id
    post "/supercategorias",     SupercategoriaController, :create
    put  "/supercategorias/:id", SupercategoriaController, :update

    get  "/categorias",     CategoriaController, :index
    get  "/categorias/:id", CategoriaController, :buscar_id
    post "/categorias",     CategoriaController, :create
    put  "/categorias/:id", CategoriaController, :update

    get    "/listas_productos",                                          ListaProductosController, :index
    get    "/listas_productos/:id",                                      ListaProductosController, :buscar_id
    post   "/listas_productos",                                          ListaProductosController, :create
    put    "/listas_productos/:id",                                      ListaProductosController, :update
    post   "/listas_productos/:lista_id/productos",                      ListaProductosController, :agregar_producto
    delete "/listas_productos/:lista_id/productos/:producto_id",         ListaProductosController, :quitar_producto

    get  "/ventas",     VentaController, :index
    get  "/ventas/:id", VentaController, :show
    post "/ventas",     VentaController, :create

    get  "/bi/productos",     BIProductoController, :index
    get  "/bi/productos/:id", BIProductoController, :show
    post "/bi/productos",     BIProductoController, :create

    get  "/bi/clientes",     BIClienteController, :index
    get  "/bi/clientes/:id", BIClienteController, :show
    post "/bi/clientes",     BIClienteController, :create

  end

    scope "/bagom", PrettycoreWeb do
    pipe_through :api

    get  "/servicios", MonteAlbanControllerBagom, :index
    post "/ventas",    MonteAlbanControllerBagom, :create
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
