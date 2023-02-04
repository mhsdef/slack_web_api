defmodule SlackWebApi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SlackWebApi.ChannelCache,
      {Task.Supervisor, name: SlackWebApi.ReqSupervisor}
    ]

    opts = [strategy: :one_for_one, name: SlackWebApi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
