defmodule Consul.MixProject do
  use Mix.Project

  def project do
    [
      app: :consulex,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.3"},
      {:jason, "~> 1.2", optional: true},
      {:poison, "~> 3.1", optional: true},
      {:yaml_elixir, "~> 2.4", optional: true}
    ]
  end
end
