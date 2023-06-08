defmodule BnApis.Helpers.WhatsappHelper do
  alias BnApis.Repo
  alias BnApis.Posts
  alias BnApis.Whatsapp.WhatsappRequest
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Helpers.WhatsappHelper
  alias BnApis.WhatsappWebhooks
  alias BnApisWeb.Helpers.PhoneHelper
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Commercials.CommercialPropertyPost

  # @created_status "created"
  # @submitted "submitted"
  # @attempted "attempted"
  # @delivered "delivered"
  # @seen "seen"

  @whatsapp_bot "whatsapp"

  def get_whatsapp_bot_employee_credential(), do: Repo.get_by(EmployeeCredential, phone_number: @whatsapp_bot)

  def create_request_params(whatsapp_request, is_media_message, button_replies, media_var) do
    values =
      whatsapp_request.template_vars
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn data, acc -> Map.put(acc, elem(data, 1), elem(data, 0)) end)

    to = whatsapp_request.to |> to_override |> format_to
    get_whatsapp_request_payload(whatsapp_request, values, to, is_media_message, button_replies, media_var)
  end

  def send_whatsapp_message(to, template, vars \\ [], opts \\ %{}, is_media_message \\ false, button_replies \\ [], media_var \\ nil) do
    to = if String.contains?(to, "+91"), do: to, else: "+91" <> to
    whatsapp_request = WhatsappRequest.create_whatsapp_request(to, template, vars, opts)
    message_request_params = WhatsappHelper.create_request_params(whatsapp_request, is_media_message, button_replies, media_var)

    {status, response} =
      ExternalApiHelper.perform(
        :post,
        "https://rcmapi.instaalerts.zone/services/rcm/sendMessage",
        message_request_params,
        headers(),
        recv_timeout: 500_000
      )

    response =
      if not is_map(response) do
        %{}
      else
        response
      end

    params = %{
      "status_code" => response["statusCode"] || Integer.to_string(status),
      "status_desc" => response["statusDesc"],
      "message_sid" => response["mid"]
    }

    whatsapp_request |> WhatsappRequest.changeset(params) |> Repo.update!()
  end

  def get_whatsapp_request_payload(whatsapp_request, values, to, false, _button_replies, _media) do
    %{
      message: %{
        channel: "WABA",
        content: %{
          preview_url: true,
          type: "TEMPLATE",
          template: %{
            templateId: whatsapp_request.template,
            parameterValues: values
          }
        },
        recipient: %{
          to: to,
          recipient_type: "individual",
          reference: %{
            cust_ref: whatsapp_request.customer_ref || "",
            messageTag1: whatsapp_request.message_tag || "",
            conversationId: whatsapp_request.conversation_id || ""
          }
        },
        sender: %{
          from: "918976799715"
        },
        preferences: %{
          webHookDNId: "1001"
        }
      },
      metaData: %{
        version: "v1.0.9"
      }
    }
  end

  def get_whatsapp_request_payload(whatsapp_request, values, to, true, button_replies, media_var) do
    values = Map.new(values)

    media =
      if(not is_nil(media_var)) do
        %{
          type: media_var["type"],
          url: media_var["url"]
        }
      else
        nil
      end

    %{
      message: %{
        channel: "WABA",
        content: %{
          preview_url: false,
          type: "MEDIA_TEMPLATE",
          mediaTemplate: %{
            templateId: whatsapp_request.template,
            bodyParameterValues: values,
            buttons: %{
              quickReplies: button_replies
            },
            media: media
          }
        },
        recipient: %{
          to: to,
          recipient_type: "individual",
          reference: %{
            cust_ref: whatsapp_request.customer_ref || "",
            messageTag1: whatsapp_request.message_tag || "",
            conversationId: whatsapp_request.conversation_id || ""
          }
        },
        sender: %{
          from: "918976799715"
        },
        preferences: %{
          webHookDNId: "1001"
        }
      },
      metaData: %{
        version: "v1.0.9"
      }
    }
  end

  def send_message_to_all_drivers(_message, _city_id) do
    %{}
  end

  def send_message_to_all_phones(_message, _phones) do
    %{}
  end

  defp headers do
    [
      {"Content-Type", "application/json"},
      {"Authentication", "Bearer " <> ApplicationHelper.get_whatsapp_token()}
    ]
  end

  defp to_override(phone_number) do
    if ApplicationHelper.get_should_send_whatsapp() == "true",
      do: phone_number,
      else: ApplicationHelper.get_default_whatsapp_number()
  end

  defp format_to(phone_number) do
    # removes spaces
    phone_number = Regex.replace(~r/\s/, phone_number, "")

    cond do
      String.match?(phone_number, ~r/^(\+)/i) ->
        phone_number |> String.replace("+", "")

      true ->
        phone_number
    end
  end

  def handle_whatsapp_webhook(params) do
    event_type = params["events"]["eventType"]
    mid = params["events"]["mid"]

    if event_type == "DELIVERY EVENTS" do
      if not is_nil(params["notificationAttributes"]) and not is_nil(params["notificationAttributes"]["status"]) do
        status = params["notificationAttributes"]["status"]

        if WhatsappRequest.fetch_whatsapp_request(mid) != nil do
          WhatsappRequest.create_or_update_whatsapp_request(%{"message_sid" => mid, "status" => status})
        end
      end
    else
      notify_whatsapp_webhook_on_slack(params)
      event_content_msg = if not is_nil(params["eventContent"]), do: params["eventContent"]["message"], else: nil
      content_type = if not is_nil(event_content_msg), do: event_content_msg["contentType"], else: nil
      owner_phone_number = if not is_nil(event_content_msg), do: event_content_msg["from"], else: ""
      owner_phone_number = PhoneHelper.maybe_remove_country_code(owner_phone_number)
      if content_type == "button", do: handle_whatsapp_button_webhook(event_content_msg["button"], owner_phone_number)
      WhatsappWebhooks.create_whatsapp_webhook_row(params)
    end
  end

  def notify_whatsapp_webhook_on_slack(payload) do
    channel = "whatsapp_webhook_dump"
    payload_message = payload |> Poison.encode!()
    ApplicationHelper.notify_on_slack("Whatsapp webhook payload - #{payload_message}", channel)
  end

  def handle_whatsapp_button_webhook(_button_response = %{"payload" => payload}, owner_phone_number) do
    button_payload = payload |> Poison.decode!()
    entity_type = button_payload["entity_type"]

    if(entity_type == "post") do
      Posts.handle_whatsapp_button_webhook(button_payload, owner_phone_number)
    end

    if(entity_type == "commercial_property_posts") do
      CommercialPropertyPost.handle_whatsapp_button_webhook(button_payload, owner_phone_number)
    end
  end

  def handle_whatsapp_button_webhook(_button_response, _owner_phone_number), do: nil

  # allow all numbers which have any country_code
  # defp maybe_insert_country_code("+" <> _ = number), do: number
  # defp maybe_insert_country_code(number), do: "+91#{number}"
end
