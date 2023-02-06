defmodule SlackWebApi.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(opts) do
    name = opts[:name] || SlackWebApi
    sup_name = Module.concat(name, "Supervisor")
    Supervisor.start_link(__MODULE__, opts, name: sup_name)
  end

  @impl true
  def init(opts) do
    bot_token = opts[:bot_token] || Application.fetch_env!(:slack_web_api, :bot_token)
    ets_table = opts[:ets_table] || :slack_channels

    children = [
      {SlackWebApi.ChannelCache, bot_token: bot_token, ets_table: ets_table},
      {Task.Supervisor, name: SlackWebApi.ReqSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
