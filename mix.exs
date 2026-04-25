defmodule SootAdmin.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :soot_admin,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Cinder table configs and LiveView components for Soot resources."
  end

  defp package do
    [licenses: ["MIT"], links: %{}]
  end

  defp deps do
    [
      {:ash, "~> 3.24"},
      {:ash_pki, path: "../ash_pki"},
      {:soot_core, path: "../soot_core"},
      {:soot_telemetry, path: "../soot_telemetry"},
      {:soot_segments, path: "../soot_segments"},
      {:cinder, "~> 0.12"},
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
