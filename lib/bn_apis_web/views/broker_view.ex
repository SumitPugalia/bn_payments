defmodule BnApisWeb.BrokerView do
  use BnApisWeb, :view
  alias BnApisWeb.BrokerView
  alias BnApis.Helpers.S3Helper
  alias BnApis.Helpers.Time
  alias BnApis.Organizations.Broker

  def render("list.json", %{brokers: brokers, has_more_brokers: has_more_brokers}) do
    %{data: render_many(brokers, BrokerView, "broker.json"), has_more_brokers: has_more_brokers}
  end

  def render("show.json", %{broker: broker}) do
    %{data: render_one(broker, BrokerView, "broker.json")}
  end

  def render("broker.json", %{broker: broker}) do
    %{
      id: broker.id,
      name: broker.name,
      profile_image: broker.profile_image,
      operating_city: broker.operating_city,
      broker_type_id: broker.broker_type_id,
      inserted_at: broker.inserted_at |> Time.naive_to_epoch(),
      rera: broker.rera,
      rera_name: broker.rera_name,
      rera_file: broker.rera_file,
      pan: broker.pan,
      pan_image: Broker.parse_broker_pan_image(broker.pan_image),
      kyc_status: broker.kyc_status,
      change_notes: broker.change_notes,
      is_pan_verified: broker.is_pan_verified,
      is_rera_verified: broker.is_rera_verified
    }
  end

  def render("team_new.json", %{admins: admins, chhotus: chhotus, pendings: pendings, pending_requests: joining_requests}) do
    %{
      admins: %{data: render_many(admins.data, BrokerView, "team_member.json"), next: admins.next},
      chhotus: %{data: render_many(chhotus.data, BrokerView, "team_member.json"), next: chhotus.next},
      pending_invites: %{data: render_many(pendings.data, BrokerView, "pending_team_member.json"), next: pendings.next},
      pending_requests: %{data: render_many(joining_requests.data, BrokerView, "joining_request.json"), next: joining_requests.next}
    }
  end

  def render("team.json", %{admins: admins, chhotus: chhotus, pendings: pendings, pending_requests: joining_requests}) do
    %{
      admins: render_many(admins, BrokerView, "team_member.json"),
      chhotus: render_many(chhotus, BrokerView, "team_member.json"),
      pending_invites: render_many(pendings, BrokerView, "pending_team_member.json"),
      pending_requests: render_many(joining_requests, BrokerView, "joining_request.json")
    }
  end

  def render("team_pagination.json", %{type: type, data: data}) do
    data_list =
      case type do
        "admin" -> render_many(data.data, BrokerView, "team_member.json")
        "chhotu" -> render_many(data.data, BrokerView, "team_member.json")
        "pending_invite" -> render_many(data.data, BrokerView, "pending_team_member.json")
        "pending_request" -> render_many(data.data, BrokerView, "joining_request.json")
      end

    %{data: data_list, next: data.next}
  end

  def render("team_member.json", %{broker: member}) do
    profile_image = member.profile_image
    profile_image = if !is_nil(profile_image) && !is_nil(profile_image["url"]), do: S3Helper.get_imgix_url(profile_image["url"])
    member |> Map.merge(%{"profile_image_url" => profile_image})
  end

  def render("pending_team_member.json", %{broker: invite}) do
    member = %{
      user_id: invite.uuid,
      name: invite.broker_name,
      phone_number: invite.phone_number,
      broker_role_id: invite.broker_role_id
    }

    member
    |> Map.merge(%{
      "profile_image_url" => nil,
      "invite_sent_time" => invite.inserted_at |> Time.naive_to_epoch()
    })
  end

  def render("joining_request.json", %{broker: joining_request}) do
    %{
      joining_request_id: joining_request.joining_request_id,
      organization_id: joining_request.organization_id,
      requestor_cred_id: joining_request.requestor_cred_id,
      requestor_broker_id: joining_request.requestor_broker_id,
      name: joining_request.requestor_name,
      phone_number: joining_request.requestor_phone_number,
      active: joining_request.active,
      status: joining_request.status,
      profile_image_url: joining_request.profile_image_url
    }
  end

  def render("index.json", %{brokers: brokers, has_more_brokers: has_more_brokers, total_count: total_count}) do
    %{
      data: render_many(brokers, BrokerView, "broker_details.json"),
      has_more_brokers: has_more_brokers,
      total_count: total_count
    }
  end

  def render("broker_details.json", %{broker: broker}) do
    %{
      active: broker.active,
      app_installed: broker.app_installed,
      polygon_id: broker.polygon_id,
      polygon_name: broker.polygon_name,
      phone_number: broker.phone_number,
      is_match_enabled: broker.is_match_enabled,
      is_cab_booking_enabled: broker.is_cab_booking_enabled,
      is_match_plus_active: broker.is_match_plus_active,
      organization_id: broker.organization_id,
      organization_name: broker.organization_name,
      organization_uuid: broker.organization_uuid,
      app_version: broker.app_version,
      manufacturer: broker.manufacturer,
      model: broker.model,
      os_version: broker.os_version,
      last_active_at: broker.last_active_at |> Time.naive_to_epoch(),
      id: broker.id,
      name: broker.name,
      profile_image: broker.profile_image,
      operating_city: broker.operating_city,
      broker_type_id: broker.broker_type_id,
      inserted_at: broker.inserted_at |> Time.naive_to_epoch(),
      max_rewards_per_day: broker.max_rewards_per_day,
      rera: broker.rera,
      rera_name: broker.rera_name,
      rera_file: broker.rera_file,
      uuid: broker.uuid,
      role_type_id: broker.role_type_id,
      homeloans_tnc_agreed: broker.homeloans_tnc_agreed,
      hl_commission_status: broker.hl_commission_status,
      hl_commission_rej_reason: broker.hl_commission_rej_reason,
      broker_commission_details: broker.broker_commission_details,
      pan_image: Broker.parse_broker_pan_image(broker.pan_image),
      kyc_status: broker.kyc_status,
      change_notes: broker.change_notes,
      is_pan_verified: broker.is_pan_verified,
      is_rera_verified: broker.is_rera_verified,
      assigned_emp_details: broker.assigned_emp_details,
      pan: broker.pan
    }
  end
end
