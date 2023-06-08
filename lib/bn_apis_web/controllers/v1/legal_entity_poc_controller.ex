defmodule BnApisWeb.V1.LegalEntityPocController do
  use BnApisWeb, :controller

  alias BnApis.Accounts.ProfileType
  alias BnApis.Stories.Invoice
  alias BnApis.Helpers.Token
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.BookingRewards
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Helpers.{Otp, Token, Connection}

  action_fallback(BnApisWeb.FallbackController)

  @legal_entity_poc "LegalEntityPoc"
  @approved_by_finance "approved_by_finance"
  @approved_by_crm "approved_by_crm"

  @rejected_by_finance "rejected_by_finance"
  @rejected_by_crm "rejected_by_crm"

  @changes_requested_invoice_status "changes_requested"

  @approved "approved"
  @rejected "rejected"
  @change "change"

  @finance_role LegalEntityPoc.poc_type_finance()
  @crm_role LegalEntityPoc.poc_type_crm()

  def send_otp(conn, params) do
    # remove request_id in future
    request_id = SecureRandom.urlsafe_base64(32)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %LegalEntityPoc{} = poc <- LegalEntityPoc.get_by_phone_number(phone_number, country_code),
         profile_type_id <- if(poc.poc_type == "Admin", do: ProfileType.legal_entity_poc_admin().id, else: ProfileType.legal_entity_poc().id),
         {:ok, %{otp: otp, otp_requested_count: stored_otp_request_count, max_count_allowed: otp_request_limit}} <-
           Otp.generate_otp_tokens(phone_number, profile_type_id) do
      message =
        "OTP is #{otp} for the Broker Network legal entity point of contact login. Valid for #{Otp.get_otp_life()} minutes. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +919373200897 to report anyone who asks for your OTP."

      phone_number
      |> Phone.append_country_code(country_code)
      |> send_otp_sms(message)

      conn
      |> put_status(:ok)
      |> json(%{
        request_id: request_id,
        otp_requested_count: stored_otp_request_count,
        max_count_allowed: otp_request_limit
      })
    else
      {:otp_error, error_message} ->
        conn |> put_status(:unprocessable_entity) |> json(error_message)

      {:error, message} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: message})

      nil ->
        {:error, "You are not registed as legal entity point of contact"}
    end
  end

  def verify_otp(conn, %{"otp" => otp} = params) do
    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %LegalEntityPoc{} = poc <- LegalEntityPoc.get_by_phone_number(phone_number, country_code),
         profile_type_id <- if(poc.poc_type == "Admin", do: ProfileType.legal_entity_poc_admin().id, else: ProfileType.legal_entity_poc().id),
         {:ok} <- Otp.verify_otp(phone_number, profile_type_id, otp),
         _ <- Token.destroy_all_user_tokens(poc.id, profile_type_id),
         {:ok, token} <- Token.initialize_legal_entity_token(poc, profile_type_id) do
      profile = Token.get_token_data(token, profile_type_id) |> Map.take(["profile"])

      conn
      |> put_status(:ok)
      |> json(%{session_token: token, profile: profile})
    else
      nil ->
        {:error, "You are not registed as legal entity point of contact"}

      {:otp_error, %{message: message}} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
    end
  end

  def validate(conn, _params) do
    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      end

    profile_type_id = ProfileType.legal_entity_poc().id

    profile =
      Token.get_token_data(session_token, profile_type_id)
      |> Map.take(["profile"])

    result = %{session_token: session_token} |> Map.merge(profile)

    conn
    |> put_status(:ok)
    |> json(result)
  end

  def validate_admin(conn, _params) do
    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      end

    profile_type_id = ProfileType.legal_entity_poc_admin().id

    profile =
      Token.get_token_data(session_token, profile_type_id)
      |> Map.take(["profile"])

    result = %{session_token: session_token} |> Map.merge(profile)

    conn
    |> put_status(:ok)
    |> json(result)
  end

  def approve(conn, %{"invoice_uuid" => invoice_uuid, "otp" => otp}) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: @legal_entity_poc}
    action = @approved
    status = get_status_by_type(logged_in_user, @approved_by_finance, @approved_by_crm)

    with true <- valid_2fa_otp?(action, invoice_uuid, logged_in_user.user_id, otp),
         {:ok, _invoice} <- Invoice.update_invoice_status_by_poc(logged_in_user.user_id, invoice_uuid, %{status: status}, user_map, action) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Sucessfully Updated!"})
    else
      false -> {:error, "Invalid OTP"}
      error -> error
    end
  end

  def reject(conn, %{"invoice_uuid" => invoice_uuid, "change_notes" => change_notes, "otp" => otp}) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: @legal_entity_poc}
    action = @rejected
    status = get_status_by_type(logged_in_user, @rejected_by_finance, @rejected_by_crm)

    with true <- valid_2fa_otp?(action, invoice_uuid, logged_in_user.user_id, otp),
         {:ok, _invoice} <- Invoice.update_invoice_status_by_poc(logged_in_user.user_id, invoice_uuid, %{status: status, change_notes: change_notes}, user_map, action) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Sucessfully Updated!"})
    else
      false -> {:error, "Invalid OTP"}
      error -> error
    end
  end

  def request_change(conn, %{"invoice_uuid" => invoice_uuid, "change_notes" => change_notes}) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: @legal_entity_poc}

    with {:ok, _invoice} <-
           Invoice.update_invoice_status_by_poc(logged_in_user.user_id, invoice_uuid, %{status: @changes_requested_invoice_status, change_notes: change_notes}, user_map, @change) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Sucessfully Updated!"})
    else
      false -> {:error, "Invalid OTP"}
      error -> error
    end
  end

  def all_invoices(conn, params) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)
    page_no = params |> Map.get("p", "1") |> String.to_integer()
    limit = params |> Map.get("limit", "30") |> String.to_integer()
    status = params |> Map.get("status", "pending")

    invoices = Invoice.all_invoices_for_poc(status, logged_in_user.user_id, logged_in_user.role_type, limit, page_no)
    next_page = if length(invoices) == limit, do: page_no + 1, else: -1

    conn
    |> put_status(:ok)
    |> json(%{data: invoices, next: next_page})
  end

  def approve_booking_reward(conn, %{"br_uuid" => br_uuid, "otp" => otp}) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: @legal_entity_poc}
    action = @approved
    status = get_status_by_type(logged_in_user, @approved_by_finance, @approved_by_crm)

    with true <- valid_2fa_otp?(action, br_uuid, logged_in_user.user_id, otp),
         {:ok, _br} <- BookingRewards.update_br_status_by_poc(logged_in_user.user_id, br_uuid, status, user_map, action) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Sucessfully Updated!"})
    else
      false -> {:error, "Invalid OTP"}
      error -> error
    end
  end

  def reject_booking_reward(conn, %{"br_uuid" => br_uuid, "otp" => otp, "change_notes" => change_notes}) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: @legal_entity_poc}
    action = @rejected
    status = get_status_by_type(logged_in_user, @rejected_by_finance, @rejected_by_crm)

    with true <- valid_2fa_otp?(action, br_uuid, logged_in_user.user_id, otp),
         {:ok, _br} <- BookingRewards.update_br_status_by_poc(logged_in_user.user_id, br_uuid, status, user_map, action, change_notes) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Sucessfully Updated!"})
    else
      false -> {:error, "Invalid OTP"}
      error -> error
    end
  end

  def request_change_booking_reward(conn, %{"br_uuid" => br_uuid, "change_notes" => change_notes}) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)
    user_map = %{user_id: logged_in_user.user_id, user_type: @legal_entity_poc}

    with {:ok, _br} <- BookingRewards.update_br_status_by_poc(logged_in_user.user_id, br_uuid, @change, user_map, @change, change_notes) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Sucessfully Updated!"})
    else
      false -> {:error, "Invalid OTP"}
      error -> error
    end
  end

  def all_booking_rewards(conn, params = %{"status" => status}) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)

    with {:ok, page, limit} <- parse_page_limit(params) do
      data_list = BookingRewards.fetch_booking_reward_leads_for_le_poc(logged_in_user.user_id, status, page, limit, logged_in_user.role_type)

      next_page = if length(data_list) == limit, do: page + 1, else: -1

      conn
      |> put_status(:ok)
      |> json(%{results: data_list, next_page: next_page})
    end
  end

  def action_otp(conn, %{"invoice_uuid" => invoice_uuid, "action" => action, "type" => type}) when action in ~w(approve reject) do
    logged_in_user = Connection.get_legal_entity_poc_logged_in_user(conn)
    status = if action == "approve", do: "approval", else: "rejection"
    otp_map = create_2fa_otp(action, invoice_uuid, logged_in_user.user_id)
    masked_invoice_number = "XXXXXX#{String.slice(invoice_uuid, -4..-1)}"

    message =
      "2FA OTP for #{status} for #{type} number #{masked_invoice_number} is: #{otp_map.otp}. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +919373200897 to report anyone who asks for your OTP."

    Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [logged_in_user.phone_number, message, true, true, "2fa_legal_entity_poc_otp"])

    conn
    |> put_status(:ok)
    |> json(%{message: "Check you regestered phone for 2FA OTP", otp: if(Mix.env() == :dev, do: otp_map.otp, else: nil)})
  end

  defp create_2fa_otp(action, invoice_uuid, user_id) do
    action = if action == "approve", do: @approved, else: @rejected
    key = Enum.join([action, invoice_uuid, user_id], "_")
    map = Otp.fetch_otp(key)
    if is_nil(map.otp), do: Otp.generate_otp(key), else: map
  end

  defp valid_2fa_otp?(action, invoice_uuid, user_id, otp) do
    key = Enum.join([action, invoice_uuid, user_id], "_")
    otp_map = Otp.fetch_otp(key)

    if otp_map.otp == otp, do: Otp.delete(key)
    otp_map.otp == otp
  end

  defp send_otp_sms(phone_number, message),
    do: Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [phone_number, message, true, true, "legal_entity_poc_login"])

  defp get_status_by_type(%{role_type: @finance_role}, finance, _crm), do: finance
  defp get_status_by_type(%{role_type: @crm_role}, _finance, crm), do: crm

  defp parse_page_limit(params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "30") |> String.to_integer()

    if page < 1 or limit > 100 do
      {:error, "invalid page or limit is too large"}
    else
      {:ok, page, limit}
    end
  end
end
