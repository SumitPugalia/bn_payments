defmodule BnApis.Organizations.OrgJoiningRequests do
  use Ecto.Schema
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.{Broker, BrokerRole}
  alias BnApis.Organizations.Schemas.OrgJoiningRequest
  alias BnApis.Helpers.S3Helper

  @limit 11

  def create_org_joining_request(
        params = %{
          "requestor_cred_id" => requestor_cred_id,
          "organization_id" => organization_id
        }
      ) do
    status = Map.get(params, "status") |> parse_status()

    case multiple_joining_request?(requestor_cred_id) do
      true ->
        {:error, "A joining request for this requestor already exists. Please wait for your request to be processed."}

      false ->
        %OrgJoiningRequest{}
        |> OrgJoiningRequest.changeset(%{
          requestor_cred_id: requestor_cred_id,
          organization_id: organization_id,
          status: status,
          active: true
        })
        |> Repo.insert()
        |> case do
          {:ok, joining_request} ->
            Task.async(fn -> send_joining_request_notifications(joining_request.requestor_cred_id, joining_request.organization_id) end)
            {:ok, joining_request}

          {:error, _error} ->
            {:error, "Invalid joining request."}
        end
    end
  end

  def cancel_org_joining_request(joining_request_id, broker_cred_id) do
    org_joining_request = fetch_org_joining_request_by_id(joining_request_id)
    valid_operation? = if not is_nil(org_joining_request), do: org_joining_request.requestor_cred_id == broker_cred_id, else: false

    case valid_operation? do
      true ->
        org_joining_request
        |> OrgJoiningRequest.changeset(%{
          status: :deleted,
          active: false
        })
        |> Repo.update()

      false ->
        {:error, "Invalid action!"}
    end
  end

  def approve_org_joining_request(joining_request_id, processed_by_cred_id) do
    org_joining_request = fetch_org_joining_request_by_id(joining_request_id)

    cond do
      is_nil(org_joining_request) ->
        {:error, "Organization joining request not found."}

      org_joining_request ->
        org_joining_request
        |> OrgJoiningRequest.changeset(%{status: :approved, processed_by_cred_id: processed_by_cred_id, active: false})
        |> Repo.update()
        |> case do
          {:ok, org_joining_request} ->
            send_status_change_push_notification(org_joining_request, processed_by_cred_id)
            {:ok, org_joining_request}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def reject_org_joining_request(joining_request_id, processed_by_cred_id) do
    org_joining_request = fetch_org_joining_request_by_id(joining_request_id)

    cond do
      is_nil(org_joining_request) ->
        {:error, "Organization joining request not found."}

      org_joining_request ->
        org_joining_request
        |> OrgJoiningRequest.changeset(%{status: :rejected, processed_by_cred_id: processed_by_cred_id, active: false})
        |> Repo.update()
        |> case do
          {:ok, org_joining_request} ->
            send_status_change_push_notification(org_joining_request, processed_by_cred_id)
            {:ok, org_joining_request}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def fetch_org_joining_request_by_id(nil), do: nil

  def fetch_org_joining_request_by_id(joining_id) do
    joining_id = if is_binary(joining_id), do: String.to_integer(joining_id), else: joining_id

    OrgJoiningRequest
    |> Repo.get_by(id: joining_id)
  end

  def fetch_org_joining_request_by_requestor_cred_id(nil), do: nil

  def fetch_org_joining_request_by_requestor_cred_id(requestor_cred_id) do
    OrgJoiningRequest
    |> where([ojr], ojr.requestor_cred_id == ^requestor_cred_id and ojr.status == :approval_pending and ojr.active == true)
    |> select([ojr], ojr.id)
    |> limit(1)
    |> Repo.one()
  end

  def fetch_pending_org_joining_requests(organization_id, page) do
    joining_requests =
      fetch_pending_joining_requests(organization_id, page)
      |> Enum.map(fn ojr ->
        profile_image = ojr.requestor_cred.broker.profile_image
        profile_image_url = if !is_nil(profile_image) && !is_nil(profile_image["url"]), do: S3Helper.get_imgix_url(profile_image["url"]), else: nil

        %{
          joining_request_id: ojr.id,
          organization_id: ojr.organization_id,
          requestor_cred_id: ojr.requestor_cred_id,
          requestor_broker_id: ojr.requestor_cred.broker_id,
          requestor_name: ojr.requestor_cred.broker.name,
          requestor_phone_number: ojr.requestor_cred.phone_number,
          active: ojr.active,
          status: ojr.status,
          profile_image_url: profile_image_url
        }
      end)

    {:ok, joining_requests}
  end

  def fetch_pending_org_joining_requests_for_credential(cred_id) do
    joining_requests =
      fetch_pending_joining_requests_for_credential(cred_id)
      |> Enum.map(fn ojr ->
        org_admin_cred = Broker.fetch_org_admin_cred(ojr.organization_id, ojr.requestor_cred.broker_id)

        if not is_nil(org_admin_cred) do
          %{
            joining_request_id: ojr.id,
            organization_id: ojr.organization_id,
            requestor_cred_id: ojr.requestor_cred_id,
            requestor_broker_id: ojr.requestor_cred.broker_id,
            organization_name: ojr.organization.name,
            admin_name: parse_for_nil(org_admin_cred, :name),
            admin_cred_id: parse_for_nil(org_admin_cred, :cred_id),
            admin_phone_number: parse_for_nil(org_admin_cred, :phone_number),
            active: ojr.active,
            status: ojr.status
          }
        end
      end)

    {:ok, Enum.filter(joining_requests, &(!is_nil(&1)))}
  end

  def expire_organization_joining_requests() do
    fetch_expired_joining_requests()
    |> Enum.each(fn ojr ->
      mark_as_expired(ojr)
    end)
  end

  def multiple_joining_request?(requestor_cred_id) do
    joining_requests =
      OrgJoiningRequest
      |> where([ojr], ojr.active == true and ojr.requestor_cred_id == ^requestor_cred_id and ojr.status == :approval_pending)
      |> Repo.all()

    length(joining_requests) > 0
  end

  def get_admin_ids_with_pending_requests() do
    OrgJoiningRequest
    |> where([ojr], ojr.active == true and ojr.status == :approval_pending)
    |> select([ojr], ojr.requestor_cred_id)
    |> Repo.all()
  end

  ## Private APIs
  defp fetch_expired_joining_requests() do
    OrgJoiningRequest
    |> where([ojr], ojr.active == true and ojr.status == :approval_pending)
    |> where([ojr], ojr.inserted_at < ^one_day_ago())
    |> Repo.all()
  end

  defp mark_as_expired(joining_request) do
    joining_request
    |> OrgJoiningRequest.changeset(%{status: :deleted, active: false})
    |> Repo.update()
  end

  defp one_day_ago() do
    NaiveDateTime.utc_now()
    |> Timex.shift(days: -1)
  end

  defp fetch_pending_joining_requests_for_credential(cred_id) do
    OrgJoiningRequest
    |> where([ojr], ojr.active == true and ojr.status == :approval_pending and ojr.requestor_cred_id == ^cred_id)
    |> preload([:organization, :requestor_cred, requestor_cred: [:broker]])
    |> Repo.all()
  end

  defp fetch_pending_joining_requests(nil, _page), do: []

  defp fetch_pending_joining_requests(org_id, page) do
    OrgJoiningRequest
    |> where([ojr], ojr.active == true and ojr.status == :approval_pending and ojr.organization_id == ^org_id)
    |> preload([:requestor_cred, requestor_cred: [:broker]])
    |> maybe_paginate(page)
    |> Repo.all()
  end

  defp maybe_paginate(query, nil), do: query

  defp maybe_paginate(query, page) do
    query
    |> limit(^@limit)
    |> offset(^((page - 1) * (@limit - 1)))
  end

  defp send_status_change_push_notification(org_joining_request, processed_by_cred_id) do
    processed_by_cred = fetch_credential(processed_by_cred_id)
    processed_by_broker = processed_by_cred.broker

    message = parse_processed_message(org_joining_request.status, processed_by_broker.name)
    broker_cred = fetch_credential(org_joining_request.requestor_cred_id)

    if not is_nil(broker_cred) and not is_nil(broker_cred.fcm_id) do
      {data, type} = get_push_notification_text(message)
      trigger_push_notification(broker_cred, %{"data" => data, "type" => type})
    end
  end

  defp parse_processed_message(:approved, name), do: "#{name} has accepted your request to join their organization"
  defp parse_processed_message(:rejected, name), do: "#{name} has declined your request to join their organization, please change your KYC details"

  defp send_joining_request_notifications(requestor_cred_id, organization_id) do
    Credential
    |> where([cred], cred.id != ^requestor_cred_id and cred.active == true and not is_nil(cred.fcm_id))
    |> where([cred], cred.broker_role_id == ^BrokerRole.admin().id and cred.organization_id == ^organization_id)
    |> Repo.all()
    |> Enum.map(fn cred ->
      requestor_cred = fetch_credential(requestor_cred_id)
      broker = requestor_cred.broker

      message = "#{broker.name} has requested to join your organization."
      {data, type} = get_push_notification_text(message)
      trigger_push_notification(cred, %{"data" => data, "type" => type})
    end)
  end

  def get_push_notification_text(message) do
    title = "Broker Network"
    intent = "com.dialectic.brokernetworkapp.actions.PROFILE.TEAM"
    type = "GENERIC_NOTIFICATION"
    data = %{"title" => title, "message" => message, "intent" => intent}
    {data, type}
  end

  def parse_broker_name(name), do: "#{name} has requested to join your organization."

  def trigger_push_notification(broker_credential, notif_data = %{"data" => _data, "type" => _type}) do
    Exq.enqueue(Exq, "broker_kyc_notification", BnApis.Notifications.PushNotificationWorker, [
      broker_credential.fcm_id,
      notif_data,
      broker_credential.id,
      broker_credential.notification_platform
    ])
  end

  defp fetch_credential(cred_id), do: Credential |> where([cred], cred.active == true and cred.id == ^cred_id) |> preload([:broker]) |> Repo.one()

  defp parse_status(nil), do: :approval_pending
  defp parse_status(""), do: :approval_pending
  defp parse_status(status) when is_binary(status), do: String.to_atom(status)
  defp parse_status(_), do: :approval_pending

  defp parse_for_nil(nil, _key), do: nil
  defp parse_for_nil(record, key), do: Map.get(record, key)
end
