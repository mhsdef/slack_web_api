defmodule SlackWebApiTest do
  use ExUnit.Case, async: true

  setup_all do
    Task.Supervisor.start_link(name: SlackWebApi.ReqSupervisor)
    [ets_table: :ets.new(:slack_channels, [:set, :public, :named_table])]
  end

  setup do
    TestServer.start()
    Application.put_env(:slack_web_api, :api_url, TestServer.url())
  end

  test "get_channel_id/2, :ok" do
    :ets.insert(:slack_channels, {"homerun", "C616161"})
    assert {:ok, "C616161"} = SlackWebApi.get_channel_id("homerun")
  end

  test "get_channel_id/2, :error" do
    assert {:error, _} = SlackWebApi.get_channel_id("strikeout")
  end

  test "get/2, 200" do
    TestServer.add("/reactions.list",
      via: :get,
      to: &set_response(&1, 200, File.read!("test/fixtures/reactions-list-200.json"))
    )

    {:ok, response} = SlackWebApi.get("/reactions.list", count: 10, limit: 10)

    assert response.status == 200
    assert response.body["ok"] == true
    assert is_list(response.body["items"])
  end

  test "join_channel/2, :sync, 200" do
    TestServer.add("/conversations.join",
      via: :post,
      to: &set_response(&1, 200, File.read!("test/fixtures/conversations-join-200.json"))
    )

    {:ok, response} = SlackWebApi.join_channel("C061EG9SL")

    assert response.status == 200
    assert response.body["ok"] == true
    assert response.body["channel"]["id"] == "C061EG9SL"
  end

  test "join_channel/2, :sync, 429" do
    TestServer.add("/conversations.join",
      via: :post,
      to: &set_response(&1, 429, ~s<{"ok": false, "error": "ratelimited"}>)
    )

    {:ok, response} = SlackWebApi.join_channel("C123456")

    assert response.status == 429
    assert response.body["ok"] == false
  end

  test "join_channel/2, :async, 200" do
    TestServer.add("/conversations.join",
      via: :post,
      to: &set_response(&1, 200, ~s<{"result": "we good here"}>)
    )

    {:ok, pid} = SlackWebApi.join_channel("C061EG9SL", :async)

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end

  test "leave_channel/2, :sync, 200" do
    TestServer.add("/conversations.leave",
      via: :post,
      to: &set_response(&1, 200, ~s<{"ok": true}>)
    )

    {:ok, response} = SlackWebApi.leave_channel("C061EG9SL")

    assert response.status == 200
    assert response.body["ok"] == true
  end

  test "leave_channel/2, :sync, 502" do
    TestServer.add("/conversations.leave",
      via: :post,
      to: &set_response(&1, 502, ~s<{"ok": false, "error": "service_unavailable"}>)
    )

    {:ok, response} = SlackWebApi.leave_channel("C123456")

    assert response.status == 502
    assert response.body["ok"] == false
  end

  test "leave_channel/2, :async, 200" do
    TestServer.add("/conversations.leave",
      via: :post,
      to: &set_response(&1, 200, ~s<{"ok": true}>)
    )

    {:ok, pid} = SlackWebApi.leave_channel("C061EG9SL", :async)

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end

  test "create_channel/1, 200" do
    TestServer.add("/conversations.create",
      via: :post,
      to: &set_response(&1, 200, File.read!("test/fixtures/conversations-create-200.json"))
    )

    {:ok, response} = SlackWebApi.create_channel("endeavor")

    assert response.status == 200
    assert response.body["ok"] == true
    assert response.body["channel"]["id"] == "C0EAQDV4Z"
  end

  test "archive_channel/2, :sync, 200" do
    TestServer.add("/conversations.archive",
      via: :post,
      to: &set_response(&1, 200, ~s<{"ok": true}>)
    )

    {:ok, response} = SlackWebApi.archive_channel("C130MSEN3")

    assert response.status == 200
    assert response.body["ok"] == true
  end

  test "archive_channel/2, :async, 200" do
    TestServer.add("/conversations.archive",
      via: :post,
      to: &set_response(&1, 200, ~s<{"ok": true}>)
    )

    {:ok, pid} = SlackWebApi.archive_channel("C130MSEN3", :async)

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end

  test "set_channel_topic/2, :sync, 200" do
    TestServer.add("/conversations.setTopic",
      via: :post,
      to: &set_response(&1, 200, File.read!("test/fixtures/conversations-settopic-200.json"))
    )

    {:ok, response} = SlackWebApi.set_channel_topic("C12345678", "Newwwww topic")

    assert response.status == 200
    assert response.body["ok"] == true
  end

  test "set_channel_topic/2, :async, 200" do
    TestServer.add("/conversations.setTopic",
      via: :post,
      to: &set_response(&1, 200, ~s<{"result": "we good here"}>)
    )

    {:ok, pid} = SlackWebApi.set_channel_topic("C12345678", "Newwwww topic", :async)

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end

  test "invite_to_channel/2, :sync, 200" do
    TestServer.add("/conversations.invite",
      via: :post,
      to: &set_response(&1, 200, File.read!("test/fixtures/conversations-invite-200.json"))
    )

    {:ok, response} =
      SlackWebApi.invite_to_channel(
        "C012AB3CD",
        ["W1234567890", "U2345678901", "U3456789012"]
      )

    assert response.status == 200
    assert response.body["ok"] == true
  end

  test "invite_to_channel/2, :async, 200" do
    TestServer.add("/conversations.invite",
      via: :post,
      to: &set_response(&1, 200, ~s<{"result": "we good here"}>)
    )

    {:ok, pid} =
      SlackWebApi.invite_to_channel(
        "C012AB3CD",
        ["W1234567890", "U2345678901", "U3456789012"],
        :async
      )

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end

  test "send_message/2, :sync, text, 200" do
    TestServer.add("/chat.postMessage",
      via: :post,
      to: &set_response(&1, 200, File.read!("test/fixtures/chat-postmessage-200.json"))
    )

    {:ok, response} = SlackWebApi.send_message(%{channel: "C123456", text: "Hola, amigo!"})

    assert response.status == 200
    assert response.body["ok"] == true
  end

  test "send_message/2, :async, blocks, 200" do
    TestServer.add("/chat.postMessage",
      via: :post,
      to: &set_response(&1, 200, ~s<{"result": "we good here"}>)
    )

    {:ok, pid} =
      SlackWebApi.send_message(
        %{
          channel: "C123456",
          attachments: ~s<[{"pretext": "pre-hello", "text": "Hello world"}]>,
          blocks:
            ~s<[{"type": "section", "text": {"type": "plain_text", "text": "Hello world"}}]}>
        },
        :async
      )

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end

  test "send_message/2, :async, text, 429 then 200" do
    TestServer.add("/chat.postMessage",
      via: :post,
      to: fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.put_resp_header("retry-after", "0")
        |> Plug.Conn.resp(429, ~s<{"result": "we bad here, backoff"}>)
      end
    )

    TestServer.add("/chat.postMessage",
      via: :post,
      to: fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, ~s<{"result": "we good here"}>)
      end
    )

    {:ok, pid} = SlackWebApi.send_message(%{channel: "C123456", text: "Some such"}, :async)

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end

  test "react_to_message/2, :sync, 200" do
    TestServer.add("/reactions.add",
      via: :post,
      to: &set_response(&1, 200, ~s<{"ok": true}>)
    )

    {:ok, response} =
      SlackWebApi.react_to_message(
        %{"channel" => "C1234567890", "ts" => "1234567890.123456"},
        "thumbsup"
      )

    assert response.status == 200
    assert response.body["ok"] == true
  end

  test "react_to_message/2, :async, 200" do
    TestServer.add("/reactions.add",
      via: :post,
      to: &set_response(&1, 200, ~s<{"ok": true}>)
    )

    {:ok, pid} =
      SlackWebApi.react_to_message(
        %{"channel" => "C1234567890", "ts" => "1234567890.123456"},
        "thumbsup",
        :async
      )

    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, _, :normal}, 500
  end

  defp set_response(conn, http_code, body) do
    conn
    |> Plug.Conn.put_resp_header("content-type", "application/json")
    |> Plug.Conn.resp(http_code, body)
  end
end
