defmodule BnApis.BrokerKitWorker do
  alias BnApis.Repo
  alias BnApis.Organizations.Broker
  alias BnApisWeb.Helpers.StoryHelper
  alias BnApis.Helpers.{ApplicationHelper}
  alias BnApis.Accounts.Credential
  alias BnApis.Accounts.ProfileType
  alias BnApis.Helpers.Token

  # @base_pdf_path "#{File.cwd!}/personalised_kit_"
  @broker_profile_type_id ProfileType.broker().id

  def perform(broker_id) do
    user = Repo.get_by(Credential, broker_id: broker_id)

    if not is_nil(user) do
      user_data = get_user_data(user.uuid)
      # portrait_pdf_path = @base_pdf_path <> "portrait_#{user_data["uuid"]}.pdf"
      # landscape_pdf_path = @base_pdf_path <> "landscape_#{user_data["uuid"]}.pdf"

      try do
        portrait_pdf_path = get_card_path(user_data, "210.0", "297.0", "0")
        landscape_pdf_path = get_card_path(user_data, "297.0", "210.0", "90")

        s3_portrait_pdf_path = Broker.upload_personalised_kit(portrait_pdf_path, user.uuid, "portrait")
        s3_landscape_pdf_path = Broker.upload_personalised_kit(landscape_pdf_path, user.uuid, "landscape")
        save_pdf_paths(s3_portrait_pdf_path, s3_landscape_pdf_path, user)

        # remove all temp files generated in the process
        remove_temp_files([portrait_pdf_path, landscape_pdf_path])
      rescue
        _ -> send_on_slack("Failed to generate Personalised Kit Url for user uuid - #{user.uuid}")
      end
    end
  end

  def get_user_data(user_uuid) do
    token_data = Token.create_token_data(user_uuid, @broker_profile_type_id, false)

    %{
      "user_id" => token_data["user_id"],
      "uuid" => token_data["uuid"],
      "phone_number" => token_data["profile"]["phone_number"],
      "organization_id" => token_data["profile"]["organization_id"],
      "organization_name" => token_data["profile"]["organization_name"],
      "firm_address" => token_data["profile"]["firm_address"],
      "broker_role_id" => token_data["profile"]["broker_role_id"],
      "profile_pic_url" => token_data["profile"]["profile_pic_url"],
      "name" => token_data["profile"]["name"],
      "test_user" => token_data["profile"]["test_user"],
      "operating_city" => token_data["profile"]["operating_city"],
      "polygon_uuid" => token_data["profile"]["locality"]["polygon_uuid"]
    }
  end

  def get_card_path(user_data, page_width, page_height, page_rotation) do
    scale = StoryHelper.get_scale(page_width |> String.to_float(), page_height |> String.to_float())
    div_top = StoryHelper.get_dynamic_top(scale)

    user_data
    |> Map.merge(%{
      "div_top" => div_top,
      "scale" => scale,
      "page_rotation" => page_rotation,
      "page_height" => page_height,
      "page_width" => page_width
    })
    |> StoryHelper.get_broker_card_path(false)
  end

  def save_pdf_paths(s3_portrait_pdf_path, s3_landscape_pdf_path, user) do
    # save these pdfs in broker personalised kit mapping table
    portrait_pdf_url = s3_portrait_pdf_path |> get_personalised_pdf_url()
    landscape_pdf_url = s3_landscape_pdf_path |> get_personalised_pdf_url()

    attrs = %{
      "portrait_kit_url" => portrait_pdf_url,
      "landscape_kit_url" => landscape_pdf_url
    }

    Broker.fetch_broker_from_id(user.broker_id)
    |> Broker.changeset(attrs)
    |> Repo.update!()

    # send_notifcation(portrait_pdf_url)
    # send_notifcation(landscape_pdf_url)
  end

  def send_notifcation(pdf_url) do
    send_on_slack("Personalised Kit Url: #{pdf_url}")
  end

  def get_personalised_pdf_url(path) do
    path |> BnApis.Helpers.S3Helper.get_imgix_url()
  end

  def remove_temp_files(files) do
    files |> Enum.each(&File.rm(&1))
  end

  def send_on_slack(text) do
    channel = ApplicationHelper.get_slack_channel()

    text
    |> ApplicationHelper.notify_on_slack(channel)
  end
end
