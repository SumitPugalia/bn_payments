defmodule BnApis.Commercial.CommercialOnboardingMessage do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialPropertyPocMapping
  alias BnApis.Buildings.Building
  alias BnApis.Places.Polygon

  @active "ACTIVE"
  @onboarding_whatsapp "comm_1"

  def perform(post_id) do
    city_ids = CommercialPropertyPost.get_city_ids_for_reminder()

    CommercialPropertyPost
    |> join(:inner, [c], b in Building, on: c.building_id == b.id)
    |> join(:inner, [c, b], p in Polygon, on: b.polygon_id == p.id)
    |> where([c, b, p], c.id == ^post_id and c.status == ^@active and p.city_id in ^city_ids)
    |> Repo.one()
    |> Repo.preload(building: [:polygon])
    |> notify_pocs()
  end

  def notify_pocs(nil), do: nil

  def notify_pocs(post) do
    CommercialPropertyPocMapping.get_commercial_poc_details(post.id)
    |> Enum.each(fn p ->
      phone_number = p.country_code <> p.phone
      values = CommercialPropertyPost.get_post_details_for_whatsapp_message(post, p.name)

      Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
        phone_number,
        @onboarding_whatsapp,
        values,
        %{"entity_type" => CommercialPropertyPost.get_schema_name(), "entity_id" => post.id},
        true,
        [],
        %{"type" => "image", "url" => CommercialPropertyPost.get_image_for_onboarding_msg(post)}
      ])
    end)
  end
end
