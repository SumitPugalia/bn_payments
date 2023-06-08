defmodule BnApis.IpLoc.HttpTest do
  use BnApis.DataCase

  alias BnApis.IpLoc.HTTP

  describe "get_loc_from_ip/2" do
    test "success when valid ip" do
      assert {:ok, data} = HTTP.get_loc_from_ip(config(), "49.36.216.11")
    end

    test "error when in-valid ip" do
      assert {:error, 200, %{"message" => "invalid query", "status" => "fail"}} = HTTP.get_loc_from_ip(config(), "49.23")
    end
  end

  defp config do
    %{base_url: "http://ip-api.com/json/", fields: "180242", key: ""}
  end
end
