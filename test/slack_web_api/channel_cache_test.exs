defmodule SlackWebApi.ChannelCacheTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    Application.put_env(:slack_web_api, :api_base_url, "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass}
  end

  @moduletag :capture_log
  test "init/1, manual insert, refresh one page", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/conversations.list", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, File.read!("test/fixtures/conversations-list-200.json"))
    end)

    {:ok, state} =
      SlackWebApi.ChannelCache.init(bot_token: "some_bot_token", ets_table: :channelcache_test)

    assert %{
             cursor: nil,
             ets_table: :channelcache_test,
             req: %Req.Request{
               method: :get,
               headers: [
                 {"authorization", "Bearer some_bot_token"},
                 {"content-type", "application/json; charset=utf-8"}
               ]
             }
           } = state

    SlackWebApi.ChannelCache.handle_cast({:insert_channel, {"testing", "C23D45576"}}, state)

    {:noreply, %{req: _req, cursor: nil}, :hibernate} =
      SlackWebApi.ChannelCache.handle_info(:fetch_channel_page, state)

    assert {:ok, "C23D45576"} = SlackWebApi.get_channel_id("testing", :channelcache_test)
    assert {:ok, "C012AB3CD"} = SlackWebApi.get_channel_id("general", :channelcache_test)
    assert {:ok, "C061EG9T2"} = SlackWebApi.get_channel_id("random", :channelcache_test)
  end

  @moduletag :capture_log
  test "handle_info/2, refresh completed" do
    {:noreply, %{req: _req, cursor: nil}, :hibernate} =
      SlackWebApi.ChannelCache.handle_info(:fetch_channel_page, %{req: %{}, cursor: ""})
  end
end
