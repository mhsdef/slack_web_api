defmodule SlackWebApi do
  @moduledoc """
  Documentation for `SlackWebApi`.
  """

  @slack_api "https://slack.com/api"
  @second_in_ms 1000

  def get_channel_id(channel_name) do
    case :ets.lookup(:slack_channels, channel_name) do
      [{_channel_name, channel_id}] -> {:ok, channel_id}
      _ -> {:error, "Slack channel not found!"}
    end
  end

  def join_channel(channel_id) do
    post("/conversations.join", %{channel: channel_id})
  end

  def leave_channel(channel_id) do
    post("/conversations.leave", %{channel: channel_id})
  end

  def create_channel(channel_name) do
    req = build_req()

    case Req.post(req, url: "/conversations.create", json: %{name: channel_name}) do
      {:ok, response} ->
        channel_id = response.body.channel.id
        GenServer.cast(SlackWebApi.ChannelCache, {:insert_channel, {channel_name, channel_id}})
        {:ok, channel_id}

      {:error, exception} ->
        {:error, exception}
    end
  end

  def archive_channel(channel_id) do
    post("/conversations.archive", %{channel: channel_id})
  end

  def set_channel_topic(channel_id, topic) do
    post("/conversations.setTopic", %{channel: channel_id, topic: topic})
  end

  def invite_to_channel(channel_id, users) do
    post("/conversations.invite", %{channel: channel_id, users: Enum.join(users, ",")})
  end

  def send_message(%{channel: _, attachments: _} = message) do
    post("/chat.postMessage", message)
  end

  def send_message(%{channel: _, blocks: _} = message) do
    post("/chat.postMessage", message)
  end

  def send_message(%{channel: _, text: _} = message) do
    post("/chat.postMessage", message)
  end

  def react_to_message(channel_id, emoji_name, message_ts) do
    post("/reactions.add", %{channel: channel_id, name: emoji_name, timestamp: message_ts})
  end

  def post(path, payload) when is_binary(path) and is_map(payload) do
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

    Req.new(base_url: @slack_api)
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
