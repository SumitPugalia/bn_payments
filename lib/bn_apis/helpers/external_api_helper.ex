defmodule BnApis.Helpers.ExternalApiHelper do
  alias BnApis.Helpers.{ApplicationHelper, SmsHelper}
  alias BnApis.Organizations.BankAccount

  @user_agent_header [
    {"User-Agent", "BrokerNetwork"},
    {"Content-Type", "application/json"},
    {"Charset", "utf-8"}
  ]

  @sales_force_auth_params ApplicationHelper.get_sales_force_auth_params()

  @sales_force_headers %{
    "Content-Type" => "application/x-www-form-urlencoded",
    "User-Agent" => "BrokerNetwork",
    "Charset" => "utf-8"
  }

  def perform(
        request_type,
        url,
        params \\ "",
        headers \\ [],
        options \\ [],
        process_response \\ true
      ) do
    headers = @user_agent_header ++ headers

    response =
      BnApis.HTTP.request(
        request_type,
        url,
        get_body_params(params),
        headers,
        options
      )

    if process_response,
      do: process_response(response),
      else: :ok
  end

  defp perform_sales_force_http_post(url, body, headers) do
    BnApis.HTTP.post(url, body, headers)
    |> process_response()
  end

  def get_youtube_video_title_by_id(video_id) do
    base_url = Application.get_env(:bn_apis, :youtube_api_base_url)
    part = "part=" <> "snippet"
    id = "id=" <> video_id
    key = "key=" <> Application.get_env(:bn_apis, :youtube_api_key)
    final_url = base_url <> part <> "&" <> id <> "&" <> key

    case BnApis.HTTP.get(final_url, [{"content-type", "application/json"}]) do
      {:ok, response} -> response |> extract_video_title()
      {:error, _response} -> ""
    end
  end

  def generate_sales_force_auth_token() do
    salesforce_auth_token_url = ApplicationHelper.get_salesforce_auth_token_url()
    body = URI.encode_query(@sales_force_auth_params)
    perform_sales_force_http_post(salesforce_auth_token_url, body, @sales_force_headers)
  end

  def post_data_to_piramal(body, bearer_token) do
    sfdc_url = ApplicationHelper.get_piramal_sfdc_url()

    headers = [
      {"Authorization", "Bearer " <> bearer_token}
    ]

    perform(:post, sfdc_url, body, headers, [], true)
  end

  def polygon_predictions(query, type \\ "city") do
    params = %{
      q: query
    }

    meta_prediction_api_url =
      ApplicationHelper.get_meta_url() <>
        "/api/v0/#{type}/predict" <> "?" <> URI.encode_query(params)

    {_status_code, response} = perform(:get, meta_prediction_api_url, "", [], [], true)

    response
  end

  def send_sms_via_mobtexting(to, message, sender) do
    url = ApplicationHelper.get_mobtexting_url()

    perform(
      :post,
      url,
      mobtexting_sms_post_body(to, message, sender),
      mobtexting_headers()
    )
  end

  def send_otp_over_call(phone_number) do
    phone_number = "91" <> phone_number
    url = ApplicationHelper.get_ivr_url()
    caller_id = ApplicationHelper.get_ivr_masked_number()
    data_url = ApplicationHelper.get_ivr_data_url()

    args = [
      "-X",
      "POST",
      url,
      "-d",
      "Url=#{data_url}",
      "-d",
      "From=#{phone_number}",
      "-d",
      "CallerId=#{caller_id}"
    ]

    System.cmd("curl", args, [])
  end

  def remove_dnd(phone_number) do
    phone_number = "0" <> phone_number
    url = ApplicationHelper.get_dnd_url()
    virtual_number = ApplicationHelper.get_virtual_number()

    args = [
      "-X",
      "POST",
      url,
      "-d",
      "VirtualNumber=#{virtual_number}",
      "-d",
      "Number=#{phone_number}",
      "-d",
      "Language=en"
    ]

    System.cmd("curl", args, [])
  end

  def validate_gst(gstin, attestr_auth_key) do
    url = ApplicationHelper.get_attestr_gstin_url()
    body = %{gstin: gstin, fetchFilings: false}

    perform(
      :post,
      url,
      body,
      attestr_headers(attestr_auth_key),
      recv_timeout: 50000
    )
  end

  def validate_pan(pan, attestr_auth_key) do
    url = ApplicationHelper.get_attestr_pan_url()
    body = %{pan: pan}

    perform(
      :post,
      url,
      body,
      attestr_headers(attestr_auth_key),
      recv_timeout: 50000
    )
  end

  def validate_upi(upi_id, attestr_auth_key) do
    url = ApplicationHelper.get_attestr_url()

    perform(
      :post,
      url,
      attestr_post_body(upi_id),
      attestr_headers(attestr_auth_key),
      recv_timeout: 50000
    )
  end

  def validate_ifsc(ifsc) do
    url = ApplicationHelper.get_razorpay_ifsc_url() <> ifsc
    perform(:get, url, "", [], [], true)
  end

  def validate_rera(rera_id, city_id) do
    url = ApplicationHelper.get_rera_validation_url()
    params = %{rera: rera_id, city_id: city_id}

    perform(:post, url, params, [], [], true)
  end

  def create_razorpay_order(
        amount,
        currency,
        auth_key
      ) do
    url = ApplicationHelper.get_razorpay_url() <> "v1/orders"
    subscription_body = %{amount: amount, currency: currency}

    perform(
      :post,
      url,
      subscription_body,
      razorpay_headers(auth_key),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  def get_razorpay_order(razorpay_order_id, auth_key) do
    url =
      ApplicationHelper.get_razorpay_url() <>
        "v1/orders/#{razorpay_order_id}"

    perform(:get, url, "", razorpay_headers(auth_key), ssl: [{:versions, [:"tlsv1.2"]}])
  end

  def capture_razorpay_order_payment(
        razorpay_payment_id,
        amount,
        currency,
        auth_key
      ) do
    url = ApplicationHelper.get_razorpay_url() <> "v1/payments/#{razorpay_payment_id}/capture"
    subscription_body = %{amount: amount, currency: currency}

    perform(
      :post,
      url,
      subscription_body,
      razorpay_headers(auth_key),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  def get_razorpay_order_payments(razorpay_order_id, auth_key) do
    url =
      ApplicationHelper.get_razorpay_url() <>
        "v1/orders/#{razorpay_order_id}/payments"

    perform(:get, url, "", razorpay_headers(auth_key), ssl: [{:versions, [:"tlsv1.2"]}])
  end

  def create_razorpay_subscription(
        plan_id,
        total_count,
        auth_key
      ) do
    url = ApplicationHelper.get_razorpay_url() <> "v1/subscriptions"
    subscription_body = %{plan_id: plan_id, total_count: total_count}

    perform(
      :post,
      url,
      subscription_body,
      razorpay_headers(auth_key),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  def get_razorpay_subscription(razorpay_subscription_id, auth_key) do
    url =
      ApplicationHelper.get_razorpay_url() <>
        "v1/subscriptions/#{razorpay_subscription_id}"

    perform(:get, url, "", razorpay_headers(auth_key), ssl: [{:versions, [:"tlsv1.2"]}])
  end

  def get_razorpay_subscription_invoices(razorpay_subscription_id, auth_key) do
    url =
      ApplicationHelper.get_razorpay_url() <>
        "v1/invoices?subscription_id=#{razorpay_subscription_id}"

    perform(:get, url, "", razorpay_headers(auth_key), ssl: [{:versions, [:"tlsv1.2"]}])
  end

  def cancel_razorpay_subscription(razorpay_subscription_id, auth_key) do
    url =
      ApplicationHelper.get_razorpay_url() <>
        "v1/subscriptions/#{razorpay_subscription_id}/cancel"

    perform(
      :post,
      url,
      %{},
      razorpay_headers(auth_key),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  def create_razorpay_contact_id(phone_number, reference_id, auth_key) do
    url = ApplicationHelper.get_razorpay_url() <> "v1/contacts"

    perform(
      :post,
      url,
      razorpay_post_body(phone_number, reference_id),
      razorpay_headers(auth_key),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  def create_razorpay_fund_account_id(razorpay_contact_id, %BankAccount{} = bank, auth_key) do
    type = "bank_account"
    url = ApplicationHelper.get_razorpay_url() <> "v1/fund_accounts"

    perform(
      :post,
      url,
      razorpay_post_body(razorpay_contact_id, bank, type),
      razorpay_headers(auth_key),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  def create_razorpay_fund_account_id(razorpay_contact_id, upi_id, auth_key) do
    type = "vpa"
    url = ApplicationHelper.get_razorpay_url() <> "v1/fund_accounts"

    perform(
      :post,
      url,
      razorpay_post_body(razorpay_contact_id, upi_id, type),
      razorpay_headers(auth_key),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  def get_fund_account_id_details(razorpay_fund_account_id, auth_key) do
    url =
      ApplicationHelper.get_razorpay_url() <>
        "v1/fund_accounts/#{razorpay_fund_account_id}"

    perform(:get, url, "", razorpay_headers(auth_key), ssl: [{:versions, [:"tlsv1.2"]}])
  end

  def get_razorpay_payout_details(razorpay_payout_id, auth_key) do
    url =
      ApplicationHelper.get_razorpay_url() <>
        "v1/payouts/#{razorpay_payout_id}"

    perform(:get, url, "", razorpay_headers(auth_key), ssl: [{:versions, [:"tlsv1.2"]}])
  end

  def get_payout_details_from_reference_id(reference_id) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()
    account_number = ApplicationHelper.get_razorpay_account_number()

    url = ApplicationHelper.get_razorpay_url() <> "v1/payouts?account_number=#{account_number}&reference_id=#{reference_id}"

    perform(
      :get,
      url,
      %{},
      razorpay_headers(auth_key),
      ssl: [{:versions, [:"tlsv1.2"]}]
    )
  end

  def get_basic_auth_header(auth_key) do
    [
      {"Authorization", "Basic #{auth_key}"}
    ]
  end

  defp attestr_post_body(upi_id) do
    %{
      vpa: upi_id
    }
  end

  defp attestr_headers(attestr_auth_key) do
    get_basic_auth_header(attestr_auth_key)
  end

  defp razorpay_headers(auth_key) do
    get_basic_auth_header(auth_key)
  end

  defp razorpay_post_body(razorpay_contact_id, %BankAccount{} = bank, type) do
    %{
      contact_id: razorpay_contact_id,
      account_type: type,
      bank_account: %{
        name: bank.account_holder_name,
        ifsc: bank.ifsc,
        account_number: bank.account_number
      }
    }
  end

  defp razorpay_post_body(razorpay_contact_id, upi_id, type) do
    %{
      contact_id: razorpay_contact_id,
      account_type: type,
      vpa: %{
        address: upi_id
      }
    }
  end

  defp razorpay_post_body(phone_number, reference_id) do
    %{
      name: "Credential #{reference_id}",
      contact: phone_number,
      type: "customer",
      reference_id: "#{reference_id}"
    }
  end

  # private functions

  defp mobtexting_sms_post_body(to, message, sender, service \\ "T") do
    %{
      sender: sender,
      to: to,
      message: message,
      service: service,
      dlr_url: SmsHelper.delivery_report_url()
    }
  end

  defp mobtexting_headers() do
    [
      {"Authorization", "Bearer " <> ApplicationHelper.get_mobtexting_token()}
    ]
  end

  defp process_response(response) do
    case response do
      {:ok,
       %HTTPoison.Response{
         status_code: status_code,
         body: response,
         headers: headers
       }}
      when status_code in 200..499 ->
        {status_code, parse_response(headers, response)}

      {_,
       %HTTPoison.Response{
         status_code: status_code,
         body: response,
         headers: headers
       }}
      when status_code in 501..599 ->
        {status_code, parse_response(headers, response)}

      {:ok,
       %HTTPoison.Response{
         status_code: status_code,
         body: response,
         headers: headers
       }}
      when status_code == 500 ->
        {status_code, parse_response(headers, response)}

      {:error, %HTTPoison.Error{id: _id, reason: reason}} ->
        {500, reason}
    end
  end

  defp parse_response(headers, response) do
    headers
    |> List.keyfind("Content-Type", 0)
    |> fetch_content_type()
    |> case do
      "application/json" ->
        Poison.decode!(response)

      _ ->
        response
    end
  end

  defp fetch_content_type(nil), do: nil

  defp fetch_content_type({"Content-Type", content_type_with_encoding}) do
    [content_type | _] = String.split(content_type_with_encoding, ";")
    content_type
  end

  defp get_body_params(body) when is_map(body), do: Poison.encode!(body)
  defp get_body_params(body) when is_list(body), do: Poison.encode!(body)
  defp get_body_params(body), do: body

  def predict_place(search_text) do
    prediction_get_args =
      %{
        input: search_text,
        key: ApplicationHelper.get_places_key(),
        # types: types,
        components: "country:in"
      }
      |> Enum.reduce("", fn {k, v}, acc -> acc <> "#{k}=#{v}" <> "&" end)

    prediction_api_url =
      ApplicationHelper.get_places_prediction_url() <>
        "?" <> prediction_get_args

    {_status_code, response} = perform(:get, URI.encode(prediction_api_url), "", [], [], true)

    response["predictions"] || []
  end

  def get_formatted_address_from_lat_lng(lat, lng) do
    addresses = get_address_from_lat_lng(lat, lng)
    address = if length(addresses) > 0, do: hd(addresses)["formatted_address"], else: ""
    place_id = if length(addresses) > 0, do: hd(addresses)["place_id"], else: ""

    %{
      "address" => address,
      "place_id" => place_id
    }
  end

  def get_address_from_lat_lng(lat, lng) do
    args =
      %{latlng: "#{lat},#{lng}", key: ApplicationHelper.get_places_key()}
      |> Enum.reduce("", fn {k, v}, acc -> acc <> "#{k}=#{v}" <> "&" end)

    reverse_geocode_api_url = ApplicationHelper.get_reverse_geocode_api_url() <> "?" <> args
    {_status_code, response} = perform(:get, URI.encode(reverse_geocode_api_url), "", [], [], true)

    response["results"] || []
  end

  def push_hl_lead_to_leadsquared(payload) do
    base_url = ApplicationHelper.get_leadsquared_url()
    access_key = ApplicationHelper.get_leadsquared_access_key()
    secret_key = ApplicationHelper.get_leadsquared_secret_key()
    url = base_url <> "/v2/LeadManagement.svc/Lead.Create"
    url = url <> "?accessKey=#{access_key}&secretKey=#{secret_key}"

    perform(
      :post,
      url,
      payload
    )
  end

  def create_user_on_sendbird(payload) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/users"

    {status_code, response} =
      perform(
        :post,
        url,
        payload,
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        response["user_id"]

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in registering a user on sendbird(NOT GETTING 200 from SENDBIRD) for cred_uuid: #{payload["user_id"]} #{Jason.encode!(payload)} #{Jason.encode!(response)}",
          channel
        )

        nil
    end
  end

  def get_user_on_sendbird(user_id) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/users/#{user_id}"

    {status_code, response} =
      perform(
        :get,
        url,
        "",
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        {:ok, response}

      400 ->
        {:error, "user not found"}

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in getting sendbird user for cred_uuid: #{user_id}",
          channel
        )

        {:error, "some error occurred"}
    end
  end

  def get_all_users_on_sendbird(params) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/users?nickname=#{params["nickname"]}&limit=#{params["limit"]}"

    {status_code, response} =
      perform(
        :get,
        url,
        "",
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        response["users"]

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in getting sendbird users for params: #{params}",
          channel
        )

        {:error, "some error occurred"}
        []
    end
  end

  def create_sendbird_channel(payload) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()

    url = "https://api-#{application_id}.sendbird.com/v3/group_channels"

    {status_code, response} =
      perform(
        :post,
        url,
        payload,
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        response["channel_url"]

      400 ->
        case response["code"] do
          400_202 ->
            payload["channel_url"]

          _ ->
            channel = ApplicationHelper.get_slack_channel()

            ApplicationHelper.notify_on_slack(
              "Issue in creating sendbird channel for channel_url: #{payload["channel_url"]}, payload: #{Jason.encode!(payload)}, response: #{Jason.encode!(response)}",
              channel
            )

            nil
        end

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in creating sendbird channel for channel_url: #{payload["channel_url"]} payload: #{Jason.encode!(payload)}, response: #{Jason.encode!(response)}",
          channel
        )

        nil
    end
  end

  def create_sendbird_channel_meta_data(meta_data, channel_url) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()

    url = "https://api-#{application_id}.sendbird.com/v3/group_channels/#{channel_url}/metadata"

    {status_code, response} =
      perform(
        :post,
        url,
        meta_data,
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        channel_url

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in creating sendbird channel metadata for channel_url(NOT GETTING 200 from SENDBIRD): #{channel_url} #{Jason.encode!(meta_data)} with response: #{Jason.encode!(response)}",
          channel
        )

        nil
    end
  end

  def update_sendbird_channel(channel_url, payload) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()

    url = "https://api-#{application_id}.sendbird.com/v3/group_channels/#{channel_url}"

    {status_code, response} =
      perform(
        :put,
        url,
        payload,
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        response["channel_url"]

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in updating sendbird channel for channel_url(NOT GETTING 200 from SENDBIRD): #{payload["channel_url"]} #{Jason.encode!(payload)}",
          channel
        )

        nil
    end
  end

  def remove_user_from_channel(payload, channel_url) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/group_channels/#{channel_url}/leave"

    {status_code, _response} =
      perform(
        :put,
        url,
        payload,
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        nil

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in removing user #{payload["user_ids"]} (NOT GETTING 200 from SENDBIRD) for channel_url: #{channel_url}",
          channel
        )
    end
  end

  def add_user_to_channel(payload, channel_url) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/group_channels/#{channel_url}/invite"

    {status_code, _response} =
      perform(
        :post,
        url,
        payload,
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        nil

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in adding user #{payload["user_ids"]} (NOT GETTING 200 from SENDBIRD) for channel_url: #{channel_url}",
          channel
        )
    end
  end

  def update_user_on_sendbird(payload, user_id) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/users/#{user_id}"

    perform(
      :put,
      url,
      payload,
      [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}]
    )
  end

  def update_user_metadata_on_sendbird(payload, user_id) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    # for now only updating phone number in metadata
    url = "https://api-#{application_id}.sendbird.com/v3/users/#{user_id}/metadata/phone_number"

    perform(
      :put,
      url,
      payload,
      [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}]
    )
  end

  def update_user_metadata_on_sendbird_without_key(payload, user_id) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/users/#{user_id}/metadata"

    perform(
      :put,
      url,
      payload,
      [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}]
    )
  end

  def delete_user_on_sendbird(user_id) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/users/#{user_id}"

    perform(
      :delete,
      url,
      "",
      [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}]
    )
  end

  def is_channel_already_exists(channel_url) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/group_channels/#{channel_url}"

    {status_code, response} =
      perform(
        :get,
        url,
        "",
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        true

      400 ->
        case response["code"] do
          400_201 ->
            false

          _ ->
            channel = ApplicationHelper.get_slack_channel()

            ApplicationHelper.notify_on_slack(
              "Issue in  getting channel_url details #{channel_url} with response code #{response["code"]} (NOT GETTING 200 from SENDBIRD)",
              channel
            )

            false
        end

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in  getting channel_url details #{channel_url} (NOT GETTING 200 from SENDBIRD)",
          channel
        )

        false
    end
  end

  def is_user_already_exist_in_channel(channel_url, user_id) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/group_channels/#{channel_url}/members/#{user_id}"

    {status_code, response} =
      perform(
        :get,
        url,
        "",
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        if not is_nil(response["is_member"]) and response["is_member"], do: true, else: false

      400 ->
        case response["code"] do
          400_201 ->
            false

          _ ->
            channel = ApplicationHelper.get_slack_channel()

            ApplicationHelper.notify_on_slack(
              "Issue in  getting user details from #{channel_url} with response: #{Jason.encode!(response)}",
              channel
            )

            false
        end

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in  getting user details from #{channel_url} with response: #{Jason.encode!(response)}",
          channel
        )

        false
    end
  end

  def fetch_users_in_sendbird_channel(channel_url) do
    application_id = ApplicationHelper.get_sendbird_application_id()
    api_token = ApplicationHelper.get_sendbird_api_token()
    url = "https://api-#{application_id}.sendbird.com/v3/group_channels/#{channel_url}/members/"

    {status_code, response} =
      perform(
        :get,
        url,
        "",
        [{"content-type", "application/json; charset=utf8"}, {"Api-Token", api_token}],
        [],
        true
      )

    case status_code do
      200 ->
        response["members"]

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in  getting user details from #{channel_url} with response: #{Jason.encode!(response)}",
          channel
        )

        []
    end
  end

  def s2c_outbound_call(params) do
    s2c_api_url = Application.get_env(:bn_apis, :s2c_api_url)

    {status_code, response} =
      perform(
        :get,
        s2c_api_url,
        params
      )

    case status_code do
      200 ->
        response

      _ ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Issue in S2C api response (NOT GETTING 200 from S2C) having status_code #{status_code} and response: #{Jason.encode!(response)} for params: #{Jason.encode!(params)}",
          channel
        )

        nil
    end
  end

  defp extract_video_title(response) do
    response = response.body |> Poison.decode!()
    item = response["items"] |> List.first()
    item["snippet"]["title"]
  end
end
