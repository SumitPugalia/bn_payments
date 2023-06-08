defmodule BnApis.Helpers.S3Helper.Behaviour do
  @callback generate_pdf_from_html_api(String.t(), String.t(), String.t(), boolean()) :: String.t()
  @callback upload_file_s3(String.t(), String.t(), any()) :: String.t()
  @callback upload_file_s3(String.t(), String.t()) :: String.t()
  @callback put_file(String.t(), String.t(), String.t(), list()) :: {:ok, String.t()} | {:error, any()}
end

defmodule BnApis.Helpers.S3Helper do
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.S3Helper.Behaviour

  @behaviour Behaviour

  def upload_file(s3_path, file_path) do
    config().upload_file_s3(s3_path, file_path)
  end

  @impl Behaviour
  def upload_file_s3(s3_path, file_path) do
    file = file_path |> File.read!()
    files_bucket = ApplicationHelper.get_files_bucket()

    case put_file(files_bucket, s3_path, file) do
      {:ok, _msg} -> s3_path
      _ -> nil
    end
  end

  def sanitize_filename(filename) do
    {:ok, cwd} = :file.get_cwd()

    case :filelib.safe_relative_path(filename, cwd) do
      :unsafe ->
        raise "Unsafe file exception"

      _ ->
        filename
    end
  end

  # TODO::MOVE to config file
  defp internal_upload_config(filename) do
    %{
      access_id: ApplicationHelper.get_access_key_id(),
      secret_key: ApplicationHelper.get_secret_access_key(),
      region: "ap-south-1",
      bucket: ApplicationHelper.get_files_bucket(),
      key: filename,
      acl: "private",
      duration: 60 * 5,
      datetime: Timex.now(),
      content_type: Path.extname(filename) |> String.slice(1..-1) |> MIME.type()
    }
  end

  defp format_datetime(datetime, "ISO8601-DATE-ONLY") do
    datetime |> Timex.format!("{YYYY}{0M}{0D}")
  end

  defp format_datetime(datetime, "ISO8601-ZERO-TIME") do
    datetime |> Timex.format!("{YYYY}{0M}{0D}T000000Z")
  end

  defp format_datetime(datetime, "ISO8601-EXTENDED") do
    datetime |> Timex.format!("{YYYY}-{0M}-{0D}T{h24}:{m}:{s}.000Z")
  end

  # Duration in seconds
  def expiration(%{duration: duration}) do
    Timex.now() |> Timex.shift(seconds: duration) |> format_datetime("ISO8601-EXTENDED")
  end

  def expiration(_config) do
    expiration(%{duration: 600})
  end

  defp credential(%{region: region, datetime: datetime, access_id: access_id}) do
    date = datetime |> format_datetime("ISO8601-DATE-ONLY")
    "#{access_id}/#{date}/#{region}/s3/aws4_request"
  end

  def policy(%{datetime: datetime, bucket: bucket, key: key, acl: acl, content_type: content_type} = config) do
    %{
      expiration: config |> expiration,
      conditions: [
        %{bucket: bucket},
        %{key: key},
        %{acl: acl},
        %{success_action_status: "201"},
        %{"Content-Type": content_type},
        %{"x-amz-credential": config |> credential},
        %{"x-amz-algorithm": "AWS4-HMAC-SHA256"},
        %{"x-amz-date": datetime |> format_datetime("ISO8601-ZERO-TIME")}
      ]
    }
    |> Poison.encode!()
    |> Base.encode64()
  end

  def signing_key(%{datetime: datetime, secret_key: secret_key, region: region}) do
    date = datetime |> format_datetime("ISO8601-DATE-ONLY")

    hmac_sha256("AWS4#{secret_key}", date)
    |> hmac_sha256(region)
    |> hmac_sha256("s3")
    |> hmac_sha256("aws4_request")
  end

  def hmac_sha256(key, data) do
    :crypto.mac(:hmac, :sha256, key, data)
  end

  def sign(policy, config) do
    signing_key(config)
    |> hmac_sha256(policy)
    |> Base.encode16(case: :lower)
  end

  def signed_post_for_internal_upload(filename) do
    config = filename |> internal_upload_config
    policy = config |> policy

    %{
      policy: policy,
      signature: policy |> sign(config),
      key: config[:key],
      acl: config[:acl],
      bucket: config[:bucket],
      success_action_status: "201",
      content_type: config[:content_type],
      credential: config |> credential,
      algorithm: "AWS4-HMAC-SHA256",
      date: config[:datetime] |> format_datetime("ISO8601-ZERO-TIME")
    }
  end

  def ex_aws_config(accelerate \\ false) do
    host = if accelerate, do: "s3-accelerate.amazonaws.com", else: "s3-ap-south-1.amazonaws.com"

    ExAws.Config.new(:s3,
      access_id: ApplicationHelper.get_access_key_id(),
      secret_key: ApplicationHelper.get_secret_access_key(),
      host: host,
      region: "ap-south-1"
    )
  end

  def file_exists?(bucket, path) do
    config = ex_aws_config()

    case ExAws.S3.head_object(bucket, path) |> ExAws.request(config) do
      {:ok, _} ->
        true

      {:error, _} ->
        false
    end
  end

  def get_file(bucket, path) do
    config = ex_aws_config()

    case ExAws.S3.get_object(bucket, path) |> ExAws.request(config) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, error} ->
        handle_s3_error(error)
    end
  end

  def get_file_list(bucket, lis_obj_opts \\ []) do
    config = ex_aws_config()

    case ExAws.S3.list_objects(bucket, lis_obj_opts) |> ExAws.request(config) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, error} ->
        handle_s3_error(error)
    end
  end

  def put_file(bucket, path, file), do: config().put_file(bucket, path, file, [])

  @impl Behaviour
  def put_file(bucket, path, file, options) do
    config = ex_aws_config()

    put_file_opts = [content_type: Path.extname(path) |> String.slice(1..-1) |> MIME.type()] ++ options

    case ExAws.S3.put_object(bucket, path, file, put_file_opts) |> ExAws.request(config) do
      {:ok, _} ->
        {:ok, "File successfully uploaded"}

      {:error, error} ->
        error
    end
  end

  def delete_file(path) do
    config = ex_aws_config()
    files_bucket = ApplicationHelper.get_files_bucket()

    case ExAws.S3.delete_object(files_bucket, path) |> ExAws.request(config) do
      {:ok, _} ->
        {:ok, "File removed successfully"}

      {:error, error} ->
        {:error, error}
    end
  end

  def presigned_get_url(bucket, object) do
    options = [expires_in: 60 * 60, virtual_host: true]
    accelerate = true
    config = ex_aws_config(accelerate)
    {:ok, get_signed_url} = ExAws.S3.presigned_url(config, :get, bucket, object, options)
    get_signed_url
  end

  def presigned_put_url(bucket, object) do
    options = [expires_in: 60 * 60, virtual_host: true]
    accelerate = true
    config = ex_aws_config(accelerate)
    {:ok, put_signed_url} = ExAws.S3.presigned_url(config, :put, bucket, object, options)
    put_signed_url
  end

  def handle_s3_error(error) do
    case error do
      {:http_error, 404, _} ->
        {:not_found, "File not found"}

      _ ->
        {:error, error}
    end
  end

  def get_imgix_url(nil), do: nil

  def get_imgix_url(path) do
    imgix_domain = ApplicationHelper.get_imgix_domain()
    "#{imgix_domain}/#{path}"
  end

  def async_delete_file(nil), do: :ok

  def async_delete_file(path) do
    domain = ApplicationHelper.get_imgix_domain()
    path = parse_file_url(String.contains?(path, domain), path, domain)
    Task.async(fn -> delete_file(path) end)
  end

  def parse_file_url(false, file_url, _domain), do: file_url
  def parse_file_url(true, file_url, domain), do: String.replace(file_url, domain <> "/", "")

  defp config do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:s3_helper, __MODULE__)
  end
end
