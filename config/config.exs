# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Load environment variables from .env file
import_config "load_env.exs"

config :prettycore,
  ecto_repos: [Prettycore.PsqlRepo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :prettycore, PrettycoreWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PrettycoreWeb.ErrorHTML, json: PrettycoreWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Prettycore.PubSub,
  live_view: [signing_salt: "i+ll0By+"],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# Configures the mailer
#
# SMTP Configuration for Gmail con opciones TLS mejoradas
# config :prettycore, Prettycore.Mailer,
#  adapter: Swoosh.Adapters.SMTP,
#  relay: "smtp.gmail.com",
#  username: "servicios.ennovacore@gmail.com",
#  password: System.get_env("SMTP_PASSWORD") || "tazooiiaqvtfobtu",
#  ssl: false,
#  tls: :always,
#  tls_options: [
#    verify: :verify_none,
#    versions: [:"tlsv1.2", :"tlsv1.3"],
#    cacerts: :public_key.cacerts_get()
#  ],
#  auth: :always,
#  port: 587,
#  retries: 3,
#  timeout: 10_000

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  prettycore: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  prettycore: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Base de datos de zonas horarias IANA
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
