defmodule SlackWebApi do
  @moduledoc """
  The Slack Web API is an interface for querying information from and
  enacting change in a Slack workspace. The Web API is a collection of
  HTTP RPC-style methods, all with URLs in the form
  https://slack.com/api/METHOD_FAMILY.method.

  See: https://api.slack.com/web
  """

  @second_in_ms 1000

  @doc """
  Returns a child specification for SlackWebApi with the given `options`.
  Both the `:name` option and the `:bot_token` option are optional, though
  the latter must be set via runtime config if not explicitly provided.

  ## Options
    * `:name` - the name of the SlackWebApi to be started
    * `:bot_token` - the bot token to use in Slack API calls
  """
  @spec child_spec(keyword) :: Supervisor.child_spec()
  defdelegate child_spec(options), to: SlackWebApi.Supervisor

  def get_channel_id(channel_name, ets_table \\ :slack_channels) do
    case :ets.lookup(ets_table, channel_name) do
      [{_channel_name, channel_id}] -> {:ok, channel_id}
      _ -> {:error, "Slack channel not found!"}
    end
  end

  def join_channel(channel_id, mode \\ :sync) do
    post("/conversations.join", %{channel: channel_id}, mode)
  end

  def leave_channel(channel_id, mode \\ :sync) do
    post("/conversations.leave", %{channel: channel_id}, mode)
  end

  def create_channel(channel_name) do
    case post("/conversations.create", %{name: channel_name}, :sync) do
      {:ok, response} ->
        channel_id = response.body["channel"]["id"]
        GenServer.cast(SlackWebApi.ChannelCache, {:insert_channel, {channel_name, channel_id}})
        {:ok, response}

      {:error, exception} ->
        {:error, exception}
    end
  end

  def archive_channel(channel_id, mode \\ :sync) do
    post("/conversations.archive", %{channel: channel_id}, mode)
  end

  def set_channel_topic(channel_id, topic, mode \\ :sync) do
    post("/conversations.setTopic", %{channel: channel_id, topic: topic}, mode)
  end

  def invite_to_channel(channel_id, users, mode \\ :sync) do
    post("/conversations.invite", %{channel: channel_id, users: Enum.join(users, ",")}, mode)
  end

  def send_message(message, mode \\ :sync)

  def send_message(%{channel: _, text: _} = message, mode) do
    post("/chat.postMessage", message, mode)
  end

  def send_message(%{channel: _, blocks: _} = message, mode) do
    post("/chat.postMessage", message, mode)
  end

  def send_message(%{channel: _, attachments: _} = message, mode) do
    post("/chat.postMessage", message, mode)
  end

  def react_to_message(channel_id, emoji_name, message_ts, mode \\ :sync) do
    post("/reactions.add", %{channel: channel_id, name: emoji_name, timestamp: message_ts}, mode)
  end

  def get(path, params) when is_binary(path) and is_list(params) do
    Req.get(build_req(), url: path, params: params)
  end

  def post(path, payload, :sync) when is_binary(path) and is_map(payload) do
    Req.post(build_req(), url: path, json: payload)
  end

  def post(path, payload, :async) when is_binary(path) and is_map(payload) do
    Task.Supervisor.start_child(
      SlackWebApi.ReqSupervisor,
      fn ->
        req = build_req()
        response = Req.post!(req, url: path, json: payload)

        if response.status == 429 do
          sleep_til_after_retry(response)
          Req.post!(req, url: path, json: payload)
        end
      end
    )
  end

  defp build_req() do
    bot_token = Application.fetch_env!(:slack_web_api, :bot_token)

    Req.new(base_url: Application.fetch_env!(:slack_web_api, :api_base_url))
    |> Req.Request.put_new_header("authorization", "Bearer " <> bot_token)
    |> Req.Request.put_new_header("content-type", "application/json; charset=utf-8")
  end

  defp sleep_til_after_retry(response) do
    response
    |> Req.Response.get_header("retry-after")
    |> List.first()
    |> String.to_integer()
    |> Kernel.*(@second_in_ms)
    |> Process.sleep()
  end
end
