defmodule SlackWebApi.ChannelCache do
  @moduledoc """
  Slack Channel Cache

  Slack, unfortunately, does not offer granular ways
  to lookup channels IDs <-> channel strings. The API
  forces iteration over the entire list of channels
  with a Slack workspace.

  Sooo, we cache the list. Every four hours we iterate
  over at the Tier 2 ratelimit threshold of 20 req/min.

  See https://api.slack.com/methods/conversations.list
  """
  use GenServer
  require Logger

  @rate_limit_ms 3000
  @next_refresh 4 * 60 * 60 * 1000

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init([{:bot_token, bot_token}, {:ets_table, ets_table}] = _opts) do
    url = Application.fetch_env!(:slack_web_api, :api_base_url) <> "/conversations.list"

    state = %{
      cursor: nil,
      ets_table: ets_table,
      req:
        Req.new(url: url)
        |> Req.Request.put_new_header("authorization", "Bearer " <> bot_token)
        |> Req.Request.put_new_header("content-type", "application/json; charset=utf-8")
    }

    :ets.new(ets_table, [:set, :protected, :named_table])
    send(self(), :fetch_channel_page)

    {:ok, state}
  end

  @impl true
  def handle_cast({:insert_channel, channel_tuple}, %{ets_table: ets_table} = state) do
    :ets.insert(ets_table, channel_tuple)
    {:noreply, state}
  end

  @impl true
  def handle_info(:fetch_channel_page, %{req: _req, cursor: ""} = state) do
    Logger.info("SlackWebApi.ChannelCache: refresh completed")
    init_next_refresh(state)
  end

  @impl true
  def handle_info(:fetch_channel_page, %{req: req, cursor: nil} = state) do
    Logger.info("SlackWebApi.ChannelCache: starting refresh")
    Req.get!(req, params: %{limit: 200}).body |> handle_page(state)
  end

  @impl true
  def handle_info(:fetch_channel_page, %{req: req, cursor: cursor} = state) do
    Req.get!(req, params: %{cursor: cursor, limit: 200}).body |> handle_page(state)
  end

  ##########################
  ##       Private        ##
  ##########################

  defp handle_page(
         %{
           "ok" => true,
           "channels" => channels,
           "response_metadata" => %{"next_cursor" => cursor}
         },
         state
       ) do
    save_channel_ids(state.ets_table, channels)
    Process.send_after(self(), :fetch_channel_page, @rate_limit_ms)
    {:noreply, %{state | cursor: cursor}}
  end

  defp handle_page(%{"ok" => true, "channels" => channels}, state) do
    save_channel_ids(state.ets_table, channels)
    init_next_refresh(state)
  end

  defp handle_page(_, state), do: init_next_refresh(state)

  defp save_channel_ids(ets_table, channels) do
    names_to_ids = Enum.map(channels, fn c -> {c["name"], c["id"]} end)
    :ets.insert(ets_table, names_to_ids)
  end

  defp init_next_refresh(state) do
    Process.send_after(self(), :fetch_channel_page, @next_refresh)
    {:noreply, %{state | cursor: nil}, :hibernate}
  end
end
