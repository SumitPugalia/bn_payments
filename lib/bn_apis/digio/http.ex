defmodule BnApis.Digio.HTTP do
  alias BnApis.Helpers.ExternalApiHelper

  def upload_doc(signers_details, file_path, url, auth_key, sign_coordinates, expire_in_days \\ 10, display_on_page \\ "custom") do
    request_params = %{
      signers: signers_details,
      expire_in_days: expire_in_days,
      display_on_page: display_on_page,
      sign_coordinates: sign_coordinates,
      send_sign_link: "true",
      notify_signers: "true"
    }

    multipart_params = {:multipart, [{"request", Poison.encode!(request_params)}, {:file, file_path, {"form-data", [{:name, "file"}, {:filename, Path.basename(file_path)}]}, []}]}
    ExternalApiHelper.perform(:post, url, multipart_params, multipart_headers(auth_key))
  end

  def download_doc(url, auth_key) do
    header = ExternalApiHelper.get_basic_auth_header(auth_key)
    ExternalApiHelper.perform(:get, url, "", header)
  end

  def generate_document_from_template(url, payload, auth_key) do
    header = ExternalApiHelper.get_basic_auth_header(auth_key)
    ExternalApiHelper.perform(:post, url, payload, header)
  end

  defp multipart_headers(auth_key) do
    ExternalApiHelper.get_basic_auth_header(auth_key) ++ [{"Content-Type", "multipart/form-data"}]
  end
end
