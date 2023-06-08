defmodule BnApis.Campaign.PrimoPass do
  alias BnApis.Repo
  alias BnApis.Campaign.Schema.PrimoPass
  alias BnApis.Helpers.ExternalApiHelper

  @base_url "https://adaniprimopass.com/_api/api/"
  @create_pass @base_url <> "create-pass"

  @otp_url @base_url <> "create-pass-otp"
  @verify_otp_url @base_url <> "create-pass-otp-verify"

  def create_pass(broker_id, pass_payload) do
    with {:ok, pass} <- maybe_create_new_pass(broker_id, pass_payload),
         {200, _otp_data} <- send_post(@otp_url, Map.take(pass_payload, ~w(contact_no))) do
      {:ok, pass.id}
    else
      {:error, %Ecto.Changeset{}} = error -> error
      {_, reason} -> {:error, transform_error_reason(reason)}
    end
  end

  def verify_otp(pass_id, otp_payload = %{"contact_no" => contact_no}) do
    with %PrimoPass{phone_number: ^contact_no, payload: pass_payload} = pass <- Repo.get_by(PrimoPass, id: pass_id),
         {200, _} <- send_post(@verify_otp_url, otp_payload),
         {200, pass_data} <- send_post(@create_pass, pass_payload),
         {:ok, _pass} <- PrimoPass.changeset(pass, %{status: :verified, pass_data: pass_data}) |> Repo.update() do
      :ok
    else
      nil -> {:error, "Please create pass first"}
      %PrimoPass{} -> {:error, "Contact number should be same as the one used while creating pass"}
      {_, reason} -> {:error, transform_error_reason(reason)}
    end
  end

  def maybe_create_new_pass(broker_id, pass_payload = %{"contact_no" => contact_no, "email" => email}) do
    create_params = %{"status" => :unverified, "phone_number" => contact_no, "email" => email, "broker_id" => broker_id, "payload" => pass_payload}

    with nil <- PrimoPass.get_pass(contact_no, email),
         {:ok, pass} <- PrimoPass.new(create_params) |> Repo.insert() do
      {:ok, pass}
    else
      %PrimoPass{} = pass -> valid_pass_for_payload(pass, pass_payload)
      {_, data} -> {:error, data}
    end
  end

  def send_post(url, data) do
    ExternalApiHelper.perform(:post, url, data, [], [])
  end

  def valid_pass_for_payload(%PrimoPass{} = pass, %{"contact_no" => input_contact_no, "email" => input_email}) do
    same_pass_request? = pass.phone_number == input_contact_no and pass.email == input_email

    cond do
      pass.status == :verified and same_pass_request? -> {:error, "Pass with this phone number and email already exists."}
      same_pass_request? -> {:ok, pass}
      pass.phone_number == input_contact_no -> {:error, "Contact number has already been taken."}
      pass.email == input_email -> {:error, "Email address has already been taken."}
    end
  end

  defp transform_error_reason([%{"errors" => error} | _]) do
    hd(Enum.map(error, &hd(elem(&1, 1))))
  end

  defp transform_error_reason([%{"message" => message} | _]) do
    message
  end

  defp transform_error_reason(error) do
    error
  end
end
