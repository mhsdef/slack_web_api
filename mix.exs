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

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.3.5"},
      {:bypass, "~> 2.1", only: :test}
    ]
  end
end
