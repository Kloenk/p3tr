defmodule P3trUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases(),
      default_release: :p3tr
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      # Dev
      {:credo, "~> 1.7.0-rc.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      fmt: ["format"],
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate"]
    ]
  end

  defp releases do
    [
      p3tr: [
        applications: [
          p3tr: :permanent
        ],
        config_providers: [
          {P3tr.Config.ReleaseRuntimeProvider, []}
        ]
      ]
    ]
  end
end
