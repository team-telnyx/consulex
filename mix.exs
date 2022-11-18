defmodule Consul.MixProject do
  use Mix.Project

  def project do
    [
      app: :consulex,
      version: "0.1.7",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: "https://github.com/team-telnyx/consulex",
      description: description(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Consul.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tesla, "~> 1.3"},
      {:jason, ">= 1.0.0", optional: true},
      {:poison, ">= 2.0.0 and < 5.0.0", optional: true},
      {:yaml_elixir, ">= 2.0.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Library for interacting with Consul on top of Tesla
    """
  end

  defp package do
    [
      maintainers: ["Guilherme Balena Versiani <guilherme@telnyx.com>"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/team-telnyx/consulex"},
      files: ~w"lib mix.exs README.md LICENSE"
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"]
    ]
  end
end
