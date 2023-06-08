defmodule BnApis.Commercial.CommercialSiteVisitNotification do
  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialSiteVisit
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Places.City

  @schedule_visit_template "comm1"
  @reminder_template "comm2"
  @cancel_visit_template "comm3"
  @visit_scheduled "SCHEDULED"
  @visit_deleted "DELETED"
  @reminder "REMINDER"

  def perform(visit_id, status) do
    site_visit = CommercialSiteVisit |> Repo.get_by(id: visit_id)
    commercial_post = CommercialPropertyPost |> Repo.get_by(id: site_visit.commercial_property_post_id) |> Repo.preload(building: [:polygon])
    city_name = City.get_city_by_id(commercial_post.building.polygon.city_id) |> Map.get(:name)
    property_details = "#{commercial_post.building.name}, #{commercial_post.building.polygon.name}, #{city_name}"
    payload = CommercialSiteVisit.create_whatsapp_request_payload(site_visit.broker_id, site_visit.visit_date, property_details)

    template_name =
      case status do
        @visit_scheduled -> @schedule_visit_template
        @visit_deleted -> @cancel_visit_template
        @reminder -> @reminder_template
      end

    commercial_post.assigned_manager_ids
    |> Enum.map(fn emp_id ->
      emp = EmployeeCredential.fetch_employee_by_id(emp_id)
      maybe_send_whatsapp_notification(payload, emp.country_code <> emp.phone_number, template_name, visit_id, emp.active)
    end)
  end

  def maybe_send_whatsapp_notification(_payload, _phone_number, _template_name, _visit_id, emp_active) when emp_active in [false, nil], do: "user not active"

  def maybe_send_whatsapp_notification(payload, phone_number, template_name, visit_id, emp_active) when emp_active == true do
    send_whatsapp_notification(payload, phone_number, template_name, visit_id)
  end

  def send_whatsapp_notification(payload, phone_number, template_name, visit_id) do
    Exq.enqueue(Exq, "send_whatsapp_message", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      phone_number,
      template_name,
      payload,
      %{"entity_type" => CommercialSiteVisit.get_schema_name(), "entity_id" => visit_id}
    ])
  end
end
