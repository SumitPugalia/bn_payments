defmodule Mix.Tasks.UpdateHlManagerPhoneNumber do
  use Mix.Task
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Helpers.ApplicationHelper

  @shortdoc "Update homeloan manager phone number on sendbird"

  def run(_) do
    Mix.Task.run("app.start", [])
    update_phone_number_on_sendbird()
  end

  def update_phone_number_on_sendbird() do
    params = %{"nickname" => "Home Loan Manager", "limit" => 100}

    ExternalApiHelper.get_all_users_on_sendbird(params)
    |> Enum.map(fn user ->
      IO.inspect("*** CHANGING PHONE NUMBER FOR USER ID : #{user["user_id"]} ***")

      meta_data = %{
        "metadata" => %{"phone_number" => ApplicationHelper.get_hl_manager_phone_number()},
        "upsert" => true
      }

      ExternalApiHelper.update_user_metadata_on_sendbird_without_key(meta_data, user["user_id"])
    end)

    # some hl agent were registered as home loan manager from front end
    params = %{"nickname" => "Homeloan Manager", "limit" => 100}

    ExternalApiHelper.get_all_users_on_sendbird(params)
    |> Enum.map(fn user ->
      IO.inspect("*** CHANGING PHONE NUMBER FOR USER ID(panel created users) : #{user["user_id"]} ***")

      meta_data = %{
        "metadata" => %{"phone_number" => ApplicationHelper.get_hl_manager_phone_number()},
        "upsert" => true
      }

      ExternalApiHelper.update_user_metadata_on_sendbird_without_key(meta_data, user["user_id"])

      # update nickname to "Home Loan Manager"
      user_payload = %{"nickname" => "Home Loan Manager"}
      IO.inspect("Updating nickname to Home Loan Manager")
      ExternalApiHelper.update_user_on_sendbird(user_payload, user["user_id"])
    end)
  end
end
