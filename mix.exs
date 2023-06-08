defmodule BnApis.MixProject do
  use Mix.Project

  def project do
    [
      app: :bn_apis,
      version: "0.0.1",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {BnApis.Application, [:exq]},
      extra_applications: [:logger, :runtime_tools, :public_key, :pdf_generator, :crypto]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.11"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.8.3"},
      {:postgrex, "~> 0.16.3"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:phoenix_live_view, "~> 0.17.7"},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
      {:floki, ">= 0.30.0", only: :test},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.19"},
      {:plug_cowboy, "~> 2.5.2"},
      {:logger_file_backend, "~> 0.0.13"},
      {:httpoison, "~> 1.8.1"},
      {:ex_aws, "~> 2.3.3"},
      {:ex_aws_s3, "~> 2.3.3"},
      {:corsica, "~> 1.2.0"},
      {:redix, "~> 1.1.5"},
      {:secure_random, "~> 0.5"},
      {:geo, "~> 3.4.3"},
      {:geo_postgis, "~> 3.4.2"},
      {:exq, "~> 0.16.2"},
      {:exq_ui, "~> 0.12.3"},
      {:timex, "~> 3.7.8"},
      {:pigeon, "~> 1.6.1"},
      {:kadabra, "~> 0.6.0"},
      {:ex_phone_number, git: "https://github.com/brokernetworkapp/ex_phone_number.git", tag: "0.3.1"},
      {:csv, "~> 2.4.1"},
      {:cors_plug, "~> 3.0.3"},
      {:quantum, "~> 3.5"},
      {:export, "~> 0.1.1"},
      {:pdf_generator, ">=0.6.2", compile: "make chrome"},
      {:distance, "~> 1.1.0"},
      {:entropy_string, "~> 1.3.4"},
      {:credo, "~> 1.6.4", only: [:dev, :test], runtime: false},
      {:bitly, "~> 0.1"},
      {:browser, "~> 0.5.1"},
      {:appsignal, "~> 2.2.14"},
      {:jason, "~> 1.3.0"},
      {:cachex, "~> 3.4.0"},
      {:appsignal_phoenix, "~> 2.1.0"},
      {:appsignal_plug, "~> 2.0.11"},
      {:poison, "~> 5.0", override: true},
      {:hackney, "~> 1.9", override: true},
      {:sweet_xml, "~> 0.7.3"},
      {:telemetry, "~> 1.0.0", override: true},
      {:faker, "~> 0.17", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:elixir_xml_to_map, "~> 3.0"},
      {:elixir_map_to_xml, "~> 0.1.0"},
      {:ex_machina, "~> 2.7.0", only: :test},
      {:randex, git: "https://github.com/ananthakumaran/randex.git", only: :test},
      {:qrcode_ex, "~> 0.1.1"},
      {:bn_payments, git: "git@github.com:brokernetworkapp/bn.payments.git", tag: "1.0.33"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "run test/seeds.exs", "test"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
