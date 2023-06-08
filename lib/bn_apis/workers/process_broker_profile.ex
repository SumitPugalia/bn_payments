defmodule BnApis.ProcessBrokerProfileWorker do
  alias BnApis.Helpers.ApplicationHelper

  @moduledoc """
  Worker responsible for processing profile image once they are created.
  It is responsible for
  1) Uploading image to S3
  2) Updating it to DB
  """

  alias BnApis.Helpers.S3Helper
  alias BnApis.Repo
  alias BnApis.Accounts
  alias BnApis.Organizations.Broker

  @doc """
  """
  def perform(credential_uuid, _retry_count \\ 1) do
    credential = Accounts.get_credential_by_uuid(credential_uuid)

    case credential.broker do
      nil ->
        IO.inspect("User/Broker not found!")

      broker ->
        if(not is_nil(broker.profile_image)) do
          temp_filepath = broker.profile_image["temp_url"]

          filename = Path.basename(temp_filepath)

          key = "#{credential.uuid}/#{filename}"
          file = File.read!(temp_filepath)
          files_bucket = ApplicationHelper.get_files_bucket()
          {:ok, _filepath} = S3Helper.put_file(files_bucket, key, file)

          profile_image = %{
            url: key
          }

          Broker.changeset(credential.broker, %{"profile_image" => profile_image})
          |> Repo.update!()
        end
    end
  end
end
