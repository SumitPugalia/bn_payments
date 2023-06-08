defmodule BnApis.PersonalisedDataWorker do
  alias BnApis.Stories
  alias BnApisWeb.Helpers.StoryHelper
  alias BnApis.Helpers.{FcmNotification, ApplicationHelper}
  alias BnApis.Accounts.Credential

  @merged_pdf_path "#{File.cwd!()}/personalised_sales_kit_"

  def perform(user_data, sales_kit_uuid) do
    personalised_pdf_path = @merged_pdf_path <> "#{sales_kit_uuid}_#{user_data["uuid"]}.pdf"
    user = Credential.get_credentials_from_uuid([user_data["uuid"]]) |> List.first()

    sales_kit = sales_kit_uuid |> Stories.get_story_sales_kit_by_uuid!()

    if sales_kit.attachment_type_id == BnApis.Stories.AttachmentType.pdf().id do
      try do
        sales_kit_pdf_file_path = sales_kit |> Stories.get_sales_kit_pdf_file_path()
        user_data = user_data |> StoryHelper.add_last_page_dimensions(sales_kit_pdf_file_path)
        broker_sales_kit_file_path = user_data |> StoryHelper.get_broker_card_path()
        # need to delete this temp file as well
        broker_sales_kit_html_path = broker_sales_kit_file_path |> String.replace("pdf", "html")
        # merges two pdfs in personalised pdf path
        sales_kit_pdf_file_path |> StoryHelper.merge_pdfs(broker_sales_kit_file_path, personalised_pdf_path)

        # upload on s3
        s3_upload_path = Stories.upload_sales_kit(personalised_pdf_path, sales_kit_uuid, user.uuid)

        # send the s3 url(imgix url) via fcm
        s3_upload_path |> send_pdf_path(user, sales_kit_uuid)

        # remove all temp files generated in the process
        remove_temp_files([
          personalised_pdf_path,
          sales_kit_pdf_file_path,
          broker_sales_kit_file_path,
          broker_sales_kit_html_path
        ])
      rescue
        _ -> send_notifcation(user, sales_kit.uuid, sales_kit.share_url)
      end
    else
      send_notifcation(user, sales_kit.uuid, sales_kit.share_url)
    end
  end

  def send_pdf_path(path, user, sales_kit_uuid) do
    pdf_url = path |> get_personalised_pdf_url()
    user |> send_notifcation(sales_kit_uuid, pdf_url)
  end

  def send_notifcation(user, uuid, pdf_url) do
    FcmNotification.send_push(
      user.fcm_id,
      %{data: %{url: pdf_url, uuid: uuid}, type: "RESPONSE_SALES_KIT_READY"},
      user.id,
      user.notification_platform
    )

    send_on_slack(pdf_url)
  end

  def get_personalised_pdf_url(path) do
    path |> BnApis.Helpers.S3Helper.get_imgix_url()
  end

  def remove_temp_files(files) do
    files |> Enum.each(&File.rm(&1))
  end

  def send_on_slack(text) do
    channel = ApplicationHelper.get_slack_channel()

    "Personalised Sales Kit Url: #{text}"
    |> ApplicationHelper.notify_on_slack(channel)
  end
end
