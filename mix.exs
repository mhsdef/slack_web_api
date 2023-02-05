defmodule SlackWebApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :slack_web_api,
      version: "0.1.0",
      elixir: "~> 1.14",
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
      {:req, "~> 0.3.5"},

      # Dev and test
      {:mox, "~> 1.0", only: :test},
      {:dialyxir, "~> 1.2.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.29.0", only: :dev, runtime: false}
    ]
  end
end
