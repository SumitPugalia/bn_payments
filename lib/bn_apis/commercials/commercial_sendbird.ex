defmodule BnApis.Commercials.CommercialSendbird do
  use Ecto.Schema
  import Ecto.Query

  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Commercials.CommercialChannelUrlMapping
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.S3Helper
  alias BnApis.Accounts.EmployeeRole

  @max_retries 5
  @delay_time 10

  def create_commercial_channel(commercial_post_id, broker_id) do
    chat_mapping =
      CommercialChannelUrlMapping
      |> where(
        [ccum],
        ccum.broker_id == ^broker_id and ccum.commercial_property_post_id == ^commercial_post_id and
          ccum.is_active == true
      )
      |> Repo.all()
      |> List.last()

    channel_url = if not is_nil(chat_mapping), do: chat_mapping.channel_url, else: nil

    case channel_url do
      nil ->
        post = Repo.get_by(CommercialPropertyPost, id: commercial_post_id) |> Repo.preload(building: [:polygon])
        # first register broker on sendbird
        credential = Credential |> Repo.get_by(broker_id: broker_id, active: true)

        case credential do
          nil ->
            {:error, "user not found"}

          credential ->
            if is_nil(credential.sendbird_user_id) do
              sendbird_user = ExternalApiHelper.get_user_on_sendbird(credential.uuid)

              case sendbird_user do
                {:ok, response} ->
                  credential |> Credential.changeset(%{"sendbird_user_id" => response["user_id"]}) |> Repo.update!()

                {:error, _msg} ->
                  broker_payload = Credential.get_sendbird_payload(credential)
                  credential_sendbird_user_id = ExternalApiHelper.create_user_on_sendbird(broker_payload)

                  if not is_nil(credential_sendbird_user_id) do
                    credential
                    |> Credential.changeset(%{"sendbird_user_id" => credential_sendbird_user_id})
                    |> Repo.update!()
                  end
              end
            end

            payload = create_commercial_sendbird_channel_payload(post, broker_id)
            channel_response = ExternalApiHelper.create_sendbird_channel(payload)

            case channel_response do
              nil ->
                Exq.enqueue_in(Exq, "commercial_sendbird", @delay_time, BnApis.Commercial.CreateCommercialChannelUrl, [
                  payload,
                  broker_id,
                  commercial_post_id,
                  @max_retries
                ])

                {:error, "Could not create channel"}

              _ ->
                if not is_nil(chat_mapping) do
                  chat_mapping
                  |> CommercialChannelUrlMapping.changeset(%{"channel_url" => channel_response})
                  |> Repo.update()
                else
                  CommercialChannelUrlMapping.insert(%{
                    "broker_id" => broker_id,
                    "commercial_property_post_id" => commercial_post_id,
                    "channel_url" => channel_response,
                    "is_active" => true
                  })
                end

                {:ok, channel_response}
            end
        end

      channel_url ->
        {:ok, channel_url}
    end
  end

  def update_commercial_channel(commercial_post_id, added_employee_ids, removed_employee_ids) do
    Exq.enqueue_in(Exq, "commercial_sendbird", @delay_time, BnApis.Commercial.UpdateCommercialChannelUsers, [
      commercial_post_id,
      added_employee_ids,
      removed_employee_ids,
      @max_retries
    ])
  end

  def register_commercial_user_on_sendbird(employee_id) do
    empl_credentials = Repo.get_by(EmployeeCredential, id: employee_id)

    if(is_nil(empl_credentials.sendbird_user_id) or empl_credentials.sendbird_user_id == "") do
      payload = get_sendbird_payload_commercial(empl_credentials)
      sendbird_user = ExternalApiHelper.get_user_on_sendbird(empl_credentials.uuid)

      case sendbird_user do
        {:ok, response} ->
          EmployeeCredential.changeset(empl_credentials, %{"sendbird_user_id" => response["user_id"]}) |> Repo.update()

        {:error, _msg} ->
          sendbird_user_response = ExternalApiHelper.create_user_on_sendbird(payload)

          case sendbird_user_response do
            nil ->
              Exq.enqueue_in(
                Exq,
                "commercial_sendbird",
                @delay_time,
                BnApis.Commercial.RegisterCommercialAssignedManager,
                [payload, empl_credentials, @max_retries]
              )

            sendbird_user_id ->
              EmployeeCredential.changeset(empl_credentials, %{"sendbird_user_id" => sendbird_user_id}) |> Repo.update()
          end
      end
    end
  end

  defp get_sendbird_payload_commercial(empl_credentials) do
    %{
      "nickname" =>
        if(empl_credentials.employee_role_id == EmployeeRole.commercial_admin().id,
          do: EmployeeRole.commercial_admin().name,
          else: EmployeeRole.commercial_agent().name
        ),
      "profile_url" => S3Helper.get_imgix_url("profile_avatar.png"),
      "user_id" => empl_credentials.uuid,
      "metadata" => %{
        "phone_number" => empl_credentials.phone_number
      }
    }
  end

  def get_all_employee_uuids(assigned_manager_ids) do
    EmployeeCredential
    |> where([e], e.id in ^assigned_manager_ids)
    |> select([e], %{uuid: e.uuid})
    |> Repo.all()
    |> Enum.map(& &1.uuid)
  end

  defp create_commercial_sendbird_channel_payload(post, broker_id) do
    assigned_manager_uuids = get_all_employee_uuids(post.assigned_manager_ids)
    broker_cred = Credential.get_credential_from_broker_id(broker_id)

    property_type =
      if not is_nil(post.is_available_for_lease) and not is_nil(post.is_available_for_purchase) and
           post.is_available_for_lease and post.is_available_for_purchase do
        "purchase & lease"
      else
        if not is_nil(post.is_available_for_lease) and post.is_available_for_lease, do: "lease", else: "purchase"
      end

    {[cover_url | _docs], _total_count} = CommercialPropertyPost.get_all_documents(post, "V1")

    %{
      "user_ids" => assigned_manager_uuids ++ [broker_cred.uuid],
      "name" => "Grade #{post.building.grade}, #{post.building.polygon.name}, #{property_type} - ##{post.id}",
      "channel_url" => "commercial_#{post.uuid}_#{broker_cred.uuid}",
      "cover_url" => cover_url.doc_url
    }
  end
end
