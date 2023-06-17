defmodule CliOpts.MixProject do
  use Mix.Project

  def project do
    [
      app: :cli_opts,
      version: "0.1.0",
      elixir: "~> 1.14",
      # build_path: "../_build",
      deps_path: "../artifacts/deps",
      build_path: "../artifacts/build",
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
      {:ex_doc, "~> 0.28", [only: :dev, runtime: false]},
      {:credo, "~> 1.6.7", [only: [:dev, :test], runtime: false]},
      {:doctor, "~> 0.21.0", [only: :dev, runtime: false]}
    ]
  end
end
