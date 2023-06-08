defmodule BnApis.Helpers.HtmlHelper.Behaviour do
  @callback generate_pdf_from_html_api(String.t(), String.t(), String.t(), boolean(), list()) :: String.t()
end

defmodule BnApis.Helpers.HtmlHelper do
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Helpers.HtmlHelper.Behaviour
  alias BnApis.Helpers.S3Helper

  @behaviour Behaviour

  def generate_pdf_from_html(html, page_width \\ "210.0", page_height \\ "297.0", delete_temporary \\ false, custom_shell_params \\ []) do
    config().generate_pdf_from_html_api(html, page_width, page_height, delete_temporary, custom_shell_params)
  end

  @impl Behaviour
  def generate_pdf_from_html_api(html, page_width, page_height, delete_temporary, shell_params) do
    with {:ok, file_path} <-
           PdfGenerator.generate(html,
             generator: :chrome,
             prefer_system_executable: true,
             delete_temporary: delete_temporary,
             shell_params: ["--page-width", page_width, "--page-height", page_height] ++ shell_params
           ),
         do: file_path
  end

  def generate_html(params, view_class, template) do
    {:safe, html} = Phoenix.View.render(view_class, template, params: params)
    html |> IO.iodata_to_binary()
  end

  def generate_image_url_from_html(html, prefix, image_config \\ %{}) do
    html_file_path = save_file(html)

    image_extension = Map.get(image_config, "image_extension", "jpg")

    image_file_path =
      case convert_to_image(html_file_path, image_config, image_extension) do
        {:ok, image_file_path} -> image_file_path
        _ -> nil
      end

    image_url =
      upload_file_with_random_suffix(image_file_path, prefix, image_extension)
      |> get_doc_url()

    delete_file(html_file_path)
    delete_file(image_file_path)
    image_url
  end

  defp upload_file_with_random_suffix(nil, _prefix, _file_extension), do: nil

  defp upload_file_with_random_suffix(file_path, prefix, file_extension) do
    file = file_path |> File.read!()
    files_bucket = ApplicationHelper.get_files_bucket()
    random_suffix = SecureRandom.urlsafe_base64(8)
    s3_path = "#{prefix}/#{random_suffix}.#{file_extension}"

    expiration = S3Helper.expiration(%{duration: 60 * 5})

    case S3Helper.put_file(files_bucket, s3_path, file, expires: expiration) do
      {:ok, _msg} -> s3_path
      _ -> nil
    end
  end

  defp get_doc_url(nil), do: nil

  defp get_doc_url(path) do
    path |> S3Helper.get_imgix_url()
  end

  def delete_file(nil), do: nil

  def delete_file(file_path) do
    File.rm(file_path)
  end

  @doc """
  Converts given HTML string into binary image.

  Returns binary data <iodata> of the generated image

  ## Options

      wkhtmltoimage_path - specify a path where wkhtmltoimage tool is installed
      format - the format of output image file. Default is JPG
  """
  def convert_to_image(html_file_path, options, image_extension) do
    image_path = Path.join(System.tmp_dir(), random_filename()) <> ".#{image_extension}"

    arguments = [
      "-a",
      System.find_executable("wkhtmltoimage"),
      "--format",
      Map.get(options, :format, "jpg"),
      "--width",
      Integer.to_string(Map.get(options, :width, 400)),
      "--quality",
      Integer.to_string(Map.get(options, :quality, 100)),
      html_file_path,
      image_path
    ]

    require Logger
    {result, status} = System.cmd(System.find_executable("xvfb-run"), arguments, stderr_to_stdout: true)
    {result, status} |> inspect() |> Logger.error()
    {result, status} = System.cmd("xvfb-run", arguments, stderr_to_stdout: true)
    {result, status} |> inspect() |> Logger.error()

    case status do
      0 -> {:ok, image_path}
      _ -> {:error, result}
    end
  end

  defp save_file(data) do
    path = Path.join(System.tmp_dir(), random_filename()) <> ".html"
    {:ok, file} = File.open(path, [:write])
    IO.binwrite(file, data)
    File.close(file)
    path
  end

  defp random_filename(length \\ 16) do
    SecureRandom.urlsafe_base64(length)
  end

  defp config do
    :bn_apis
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:html_helper, __MODULE__)
  end
end
