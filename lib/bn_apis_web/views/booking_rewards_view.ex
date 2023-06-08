defmodule BnApisWeb.V1.BookingRewardsView do
  use BnApisWeb, :view
  alias BnApis.Helpers.S3Helper
  alias BnApis.BookingRewards.Status
  alias BnApis.BookingRewards

  def render("show.json", %{booking_rewards_lead: booking_rewards_lead}) do
    %{
      "unit_details" => get_unit_details(booking_rewards_lead),
      "booking_client" => get_booking_client_details(booking_rewards_lead.booking_client),
      "booking_payment" => get_booking_payment_details(booking_rewards_lead.booking_payment),
      "latest_status" => BookingRewards.get_latest_status(booking_rewards_lead.status_id),
      "latest_status_for_dev_eco" => Status.get_status_from_id(booking_rewards_lead.status_id)
    }
  end

  def render("invoice_details.json", %{booking_rewards_lead: brl}) do
    %{
      "story_id" => brl.story.id,
      "uuid" => brl.story.uuid,
      "story" => %{
        "story_name" => brl.story.name,
        "developer_name" => brl.story.developer.name
      },
      "legal_entity" => %{
        "id" => brl.legal_entity.id,
        "uuid" => brl.legal_entity.uuid,
        "legal_entity_name" => brl.legal_entity.legal_entity_name
      },
      "invoice_items" => [
        %{
          "customer_name" => brl.booking_client.name,
          "unit_number" => brl.unit_number,
          "wing_name" => brl.wing,
          "building_name" => brl.building_name,
          "agreement_value" => brl.agreement_value
        }
      ],
      "billing_company" => %{
        "bank_account" => %{
          "account_number" => brl.billing_company.bank_account.account_number
        },
        "id" => brl.billing_company.id,
        "name" => brl.billing_company.name,
        "address" => brl.billing_company.address,
        "gst" => brl.billing_company.gst,
        "rera_id" => brl.billing_company.rera_id
      }
    }
  end

  defp get_unit_details(nil), do: nil

  defp get_unit_details(brl) do
    %{
      "booking_date" => brl.booking_date,
      "booking_form_number" => brl.booking_form_number,
      "rera_number" => brl.rera_number,
      "unit_number" => brl.unit_number,
      "rera_carpet_area" => brl.rera_carpet_area,
      "building_name" => brl.building_name,
      "wing" => brl.wing,
      "agreement_value" => brl.agreement_value,
      "agreement_proof" => S3Helper.get_imgix_url(brl.agreement_proof),
      "story_id" => brl.story_id,
      "story_name" => brl.story.name,
      "developer_name" => brl.story.developer.name,
      "broker_id" => brl.broker_id,
      "broker_name" => brl.broker.name,
      "status_message" => brl.status_message,
      "legal_entity_id" => brl.legal_entity_id,
      "latest_status" => BookingRewards.get_latest_status(brl.status_id),
      "latest_status_for_dev_eco" => Status.get_status_from_id(brl.status_id)
    }
  end

  defp get_booking_client_details(nil), do: nil

  defp get_booking_client_details(bcl) do
    %{
      "name" => bcl.name,
      "pan_number" => bcl.pan_number,
      "pan_card_image" => S3Helper.get_imgix_url(bcl.pan_card_image),
      "permanent_address" => bcl.permanent_address,
      "address_proof" => S3Helper.get_imgix_url(bcl.address_proof)
    }
  end

  defp get_booking_payment_details(nil), do: nil

  defp get_booking_payment_details(bp) do
    %{
      "token_amount" => bp.token_amount,
      "payment_mode" => bp.payment_mode,
      "payment_proof" => S3Helper.get_imgix_url(bp.payment_proof)
    }
  end
end
