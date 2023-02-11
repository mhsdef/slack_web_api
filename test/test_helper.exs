ExUnit.start()
Logger.configure(level: :notice)
Application.put_env(:slack_web_api, :bot_token, "unit-test-bot-token")
