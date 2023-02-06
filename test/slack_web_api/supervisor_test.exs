defmodule SlackWebApi.SupervisorTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    Application.put_env(:slack_web_api, :api_base_url, "http://localhost:#{bypass.port}")
    {:ok, bypass: bypass}
  end

  test "init/1" do
    {:ok, _pid} = SlackWebApi.Supervisor.start_link(ets_table: :supervisor_test)

    assert [
             {SlackWebApi.ReqSupervisor, _, _, _},
             {SlackWebApi.ChannelCache, _, _, _}
           ] = Supervisor.which_children(SlackWebApi.Supervisor)
  end
end
