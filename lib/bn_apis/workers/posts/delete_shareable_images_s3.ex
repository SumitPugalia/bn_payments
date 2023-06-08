defmodule BnApis.Posts.DeleteShareableImagesS3 do
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Posts.ResalePropertyPost
  alias BnApis.Helpers.S3Helper

  def perform() do
    delete_shareable_images_s3()
  end

  def delete_shareable_images_s3() do
    files_bucket = ApplicationHelper.get_files_bucket()

    body_contents =
      case S3Helper.get_file_list(files_bucket, prefix: ResalePropertyPost.s3_prefix_reshareable_image()) do
        {:ok, body} -> body[:contents]
        {:error, _msg} -> []
      end

    s3_keys_to_be_deleted = Enum.map(body_contents, fn content -> content[:key] end)
    Enum.map(s3_keys_to_be_deleted, fn key -> S3Helper.async_delete_file(key) end)
  end
end
