defmodule BnApis.Signzy.HTTPTest do
  use BnApis.DataCase

  alias BnApis.Signzy.HTTP

  describe "Test Signzy end to end flow" do
    test "" do
      assert {200, data} = HTTP.login(config())
      config = Map.put(config(), :access_token, data["id"]) |> Map.put(:userId, data["userId"])
      assert {200, data} = HTTP.create_identity_object(config)
      config = Map.put(config, :item_access_token, data["accessToken"])
      # Enter Valid PAN and PAN Holder's Name
      assert {_, data} = HTTP.validate_pan_number(config, "ABCDE1234F", "ENTER_VALID_DATA", data["id"])
    end
  end

  defp config do
    %{
      base_url: "https://preproduction.signzy.tech/api/v2",
      username: "brokernetwork_test",
      password: "aYG6T77rVMjFdp3HSm2u"
    }
  end
end
