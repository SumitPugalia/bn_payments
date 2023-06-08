defmodule BnApisWeb.S3Controller do
  use BnApisWeb, :controller

  alias BnApis.Helpers.{S3Helper, ApplicationHelper}

  def protected_signed_url(conn, %{"resource_name" => resource_name, "filename" => filename}) do
    filename = S3Helper.sanitize_filename(filename)
    random_prefix = SecureRandom.urlsafe_base64(8)
    key = "#{resource_name}/#{random_prefix}/#{filename}"
    files_bucket = ApplicationHelper.get_files_bucket()
    get_signed_url = S3Helper.presigned_get_url(files_bucket, key)

    conn
    |> put_status(:ok)
    |> json(%{signedURL: get_signed_url, postForm: S3Helper.signed_post_for_internal_upload(key)})
  end
end
