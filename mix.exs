defmodule Prettycore.MixProject do
  use Mix.Project

  def project do
    [
      app: :prettycore,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {Prettycore.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto, :ssh]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Framework principal
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},

      # Conector PostgreSQL (para auth)
      {:postgrex, ">= 0.0.0"},

      # Frontend / LiveView
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:heroicons, github: "tailwindlabs/heroicons", tag: "v2.2.0", app: false, compile: false},

      # Build de assets
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},

      # Paginación y filtros
      {:flop, "~> 0.25"},
      {:flop_phoenix, "~> 0.23"},

      # Utilidades
      {:swoosh, "~> 1.16"},
      # ← AQUÍ VA (SMTP para enviar correos reales)
      {:gen_smtp, "~> 1.2"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Excel export
      {:elixlsx, "~> 0.6.0"},

      # Password hashing seguro (puro Elixir, no requiere compilador C)
      {:pbkdf2_elixir, "~> 2.0"},

      # Zonas horarias completas (IANA tzdata)
      {:tzdata, "~> 1.1"},

      # Test
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind prettycore", "esbuild prettycore"],
      "assets.deploy": [
        "tailwind prettycore --minify",
        "esbuild prettycore --minify",
        "phx.digest"
      ],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
