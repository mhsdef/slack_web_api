ExUnit.start()
Application.put_env(:slack_web_api, :bot_token, "unit-test-bot-token")
Application.ensure_all_started(:bypass)
