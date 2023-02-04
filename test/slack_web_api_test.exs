defmodule SlackWebApiTest do
  use ExUnit.Case
  doctest SlackWebApi

  test "get_channel_id/1 fail" do
    assert SlackWebApi.get_channel_id("strikeout") == {:error, _}
  end
end
