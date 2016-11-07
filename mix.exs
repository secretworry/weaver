defmodule Weaver.Mixfile do
  use Mix.Project

  def project do
    [app: :weaver,
     version: "0.1.0",
     elixir: "~> 1.3",
     deps: deps(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     # Hex
     description: description(),
     package: package()]
  end

  def description do
    """
    Weave objects together by their external ids
    """
  end

  def package do
    [maintainers: ["Siyu DU"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/secretworry/weaver"},
     files: ~w(mix.exs README.md lib) ++
             ~w(test)]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev}]
  end
end
