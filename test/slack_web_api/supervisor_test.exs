defmodule SlackWebApi.SupervisorTest do
  use ExUnit.Case, async: true

  test "init/1" do
    {:ok, _pid} = SlackWebApi.Supervisor.start_link(ets_table: :supervisor_test)

    assert [
             {SlackWebApi.ReqSupervisor, _, _, _},
             {SlackWebApi.ChannelCache, _, _, _}
           ] = Supervisor.which_children(SlackWebApi.Supervisor)
  end
end
