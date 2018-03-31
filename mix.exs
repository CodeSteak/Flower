defmodule Flower.MixProject do
  use Mix.Project

  def project do
    [
      app: :flower,
      name: "flower",
      version: "0.1.1",
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: [:rustler] ++ Mix.compilers(),
      rustler_crates: rustler_crates(),
      package: package(),
      description: description(),
      deps: deps(),
      source_url: "https://github.com/CodeSteak/Flower",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  defp package() do
    [
      maintainers: ["Codesteak"],
      licenses: ["MIT"],
      links: %{
        "Source" => "https://github.com/CodeSteak/Flower"
      }
    ]
  end

  def description() do
    """
    This is an implementation of Bloom Filters for Elixir. It uses Rust NIFs for better performance.
    """
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
      {:rustler, "~> 0.16.0"},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end

  defp rustler_crates do
    [
      bitarray: [
        path: "native/bitarray",
        mode: rustc_mode(Mix.env())
      ]
    ]
  end

  defp rustc_mode(:prod), do: :release
  defp rustc_mode(_), do: :debug
end
