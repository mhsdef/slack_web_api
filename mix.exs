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
      {:req, "~> 0.4.3"},
      {:bandit, "~> 0.7.4", only: :test},
      {:test_server, "~> 0.1.8", only: :test}
    ]
  end
end
