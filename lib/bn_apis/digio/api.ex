defmodule BnApis.Digio.API do
  alias BnApis.Digio.HTTP
  alias BnApis.Helpers.{ApplicationHelper, S3Helper}
  alias BnApis.AssistedProperty.Schema.AssistedPropertyPostAgreement
  alias BnApis.Documents.Document
  alias BnApis.Digio.DigioDocs
  alias BnApis.AssistedProperty
  alias BnApis.Helpers.WebhookHelper

  require Logger

  @doc_signed_event_type "doc.signed"

  def new() do
    config = Application.get_env(:bn_apis, __MODULE__, [])
    username = Keyword.fetch!(config, :digio_username)
    password = Keyword.fetch!(config, :digio_password)
    auth_key = Base.encode64("#{username}:#{password}")

    %{
      api_base_url: Keyword.fetch!(config, :digio_api_base_url),
      esign_base_url: Keyword.fetch!(config, :digio_esign_base_url),
      auth_key: auth_key
    }
  end

  def fetch_template_key_by_name(template_name) do
    case template_name do
      "assisted_owner_agreement" -> "TMP230125191102497O7KPGSSJJL5MT7"
    end
  end

  def generate_sign_coordinates_for_template(template_name, owner_number) do
    case template_name do
      "assisted_owner_agreement" ->
        cooridnates = %{
          "2": [
            %{
              llx: 69.00001024390245,
              lly: 208.003220962867,
              urx: 206.99536085365855,
              ury: 248.00026597582038
            }
          ]
        }

        Map.put(%{}, owner_number, cooridnates)
    end
  end

  def upload_pdf_for_digio(file_path, signers_details, sign_coordinates, digio_params) do
    config = new()
    url = config.api_base_url <> "/v2/client/document/upload"
    {status_code, response} = get_module().upload_doc(signers_details, file_path, url, config.auth_key, sign_coordinates)

    case status_code do
      200 ->
        esign_link_map = generate_esign_links(config.esign_base_url, response["id"], response["signing_parties"])
        response = Map.put(response, "esign_link_map", esign_link_map) |> Map.merge(digio_params)
        DigioDocs.create_doc_details(response)

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Digio Upload PDF Issue:
            Response : #{inspect(response)}",
          channel
        )

        nil
    end
  end

  def generate_esign_links(_esign_base_url, doc_id, signing_parties) when is_nil(doc_id) or is_nil(signing_parties), do: nil

  def generate_esign_links(esign_base_url, doc_id, signing_parties) do
    Enum.reduce(signing_parties, [], fn signing_party, acc ->
      random_suffix = SecureRandom.urlsafe_base64(8)
      esign_url = esign_base_url <> "/#/gateway/login/#{doc_id}/#{random_suffix}/#{signing_party["identifier"]}"
      acc ++ [%{identifier: signing_party["identifier"], esign_doc_url: esign_url, signer_name: signing_party["name"]}]
    end)
  end

  def generate_document_from_template(payload) do
    config = new()
    url = config.api_base_url <> "/v2/client/template/multi_templates/generate_doc_and_merge"

    with {200, response_body} <- get_module().generate_document_from_template(url, payload, config.auth_key) do
      file_path = Path.join(System.tmp_dir(), SecureRandom.urlsafe_base64(8)) <> ".pdf"
      File.write(file_path, response_body)
      file_path
    else
      {_, _error} ->
        nil
    end
  end

  def fetch_template_params_to_generate_documents(template_name, template_params, image_params \\ nil) do
    template_key = fetch_template_key_by_name(template_name)

    template_params = %{
      template_key: template_key,
      template_values: template_params
    }

    if not is_nil(image_params), do: Map.merge(template_params, %{images: image_params}), else: template_params
  end

  def download_document_from_digio(doc_id) do
    config = new()
    url = config.api_base_url <> "/v2/client/document/download?document_id=#{doc_id}"

    with {200, response_body} <- get_module().download_doc(url, config.auth_key) do
      file_path = Path.join(System.tmp_dir(), SecureRandom.urlsafe_base64(8)) <> ".pdf"
      File.write(file_path, response_body)
      file_path
    else
      {_, error} ->
        notify_on_slack("Digio Download PDF Issue:\n Response : #{inspect(error)}")
        nil
    end
  end

  def download_and_save_doc(doc_id, s3_path) do
    file_path = download_document_from_digio(doc_id)
    S3Helper.upload_file_s3(s3_path, file_path) |> S3Helper.get_imgix_url()
  end

  def save_signed_agreement(doc_url, doc_name, doc_type, entity_id, entity_type, employee_id) do
    document = %{
      "doc_url" => doc_url,
      "entity_id" => entity_id,
      "doc_name" => doc_name,
      "is_active" => true,
      "type" => doc_type,
      "priority" => 1
    }

    Document.upload_document([document], employee_id, entity_type, "employee")
  end

  def handle_webhook(params) do
    payload = params["payload"]
    event_type = params["event"]
    channel = "digio_webhook_dump"
    payload_message = params |> Poison.encode!()

    case event_type do
      @doc_signed_event_type ->
        doc_params = payload["document"]
        doc_details = DigioDocs.get_doc_details_by(%{id: doc_params["id"]})

        with false <- is_nil(doc_details),
             digio_doc <- DigioDocs.update_doc_details(doc_details.id, doc_params) do
          notify_on_slack("Digio webhook payload - #{payload_message}", channel)
          take_entity_type_specific_actions(digio_doc, event_type)
        else
          true ->
            notify_on_slack("Digio Doc doesn't exist against this webhook payload - \n#{payload_message}", channel)

          _ ->
            notify_on_slack("Error Updating Digio Doc details,\n webhook payload - #{payload_message}", channel)
        end

      "_" ->
        notify_on_slack("New Event type detected - #{event_type}, \nPayload - #{payload_message}", channel)
    end
  end

  def take_entity_type_specific_actions(digio_doc, @doc_signed_event_type) do
    cond do
      digio_doc.entity_type == AssistedPropertyPostAgreement.schema_name() ->
        entity_id = digio_doc.entity_id

        with %AssistedPropertyPostAgreement{} = assisted_property_post_agreement <- AssistedProperty.get_assisted_property_by(%{id: entity_id}) do
          bn_doc_url = download_and_save_doc(digio_doc.id, "assisted/owner_agreement_#{assisted_property_post_agreement.uuid}.pdf")
          employee = WebhookHelper.get_webhook_bot_employee_credential()

          save_signed_agreement(
            bn_doc_url,
            "owner_agreement_#{assisted_property_post_agreement.uuid}",
            "agreement",
            assisted_property_post_agreement.id,
            AssistedPropertyPostAgreement.schema_name(),
            employee.id
          )

          AssistedProperty.update_assisted_record(assisted_property_post_agreement, %{owner_agreement_status: :signed})
        else
          nil -> Logger.error("Assisted Property Post Agreement doesn't exist with ID - #{entity_id}")
        end

      true ->
        nil
    end
  end

  defp notify_on_slack(mssg, channel \\ nil) do
    channel = if is_nil(channel), do: ApplicationHelper.get_slack_channel(), else: channel
    ApplicationHelper.notify_on_slack(mssg, channel)
  end

  defp get_module() do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:module_name, HTTP)
  end
end
