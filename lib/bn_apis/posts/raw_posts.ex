defmodule BnApis.Posts.RawPosts do
  import Ecto.Query, warn: false

  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Posts.RawRentalPropertyPost
  alias BnApis.Posts.RawResalePropertyPost

  @junk_reasons [
    "Number Does Not Exist",
    "Wrong Number",
    "Not Interested",
    "Not Ready To Disclose",
    "Not a Owner",
    "Third Party Calling",
    "Broker and Channel Partner",
    "Builder and Development",
    "Do Not Call",
    "Did Not Apply",
    "Old Follow up call",
    "Already Posted",
    "Already Rent Out",
    "Already Sold",
    "Want To Go On Rent",
    "Want To Purchase",
    "General Enquiry",
    "Test Call",
    "Commercial",
    "Plot",
    "Non Workable Locality",
    "Interested Non Workable Locality",
    "Not Eligible",
    "Language Barrier",
    "Lead Lost After Multiple Attempts",
    "Duplicate Number"
  ]

  @unanswered_reasons [
    "Switched Off",
    "Disconnected The Call",
    "Number Busy",
    "Ringing No Response",
    "Not Reachable",
    "DNP-Incorrect Details"
  ]

  def junk_reasons() do
    @junk_reasons
  end

  def unanswered_reasons() do
    @unanswered_reasons
  end

  def handle_fb_webhook(user_map, payload) do
    if not is_nil(payload["Phone Number"]) do
      {country_code, phone} = parse_phone_number(payload["Phone Number"])

      params = %{
        "source" => "facebook",
        "country_code" => country_code,
        "phone" => phone,
        "name" => payload["Full Name"],
        "city" => "Mumbai",
        "address" => payload["Locality"],
        "utm_campaign" => payload["Campaign Name"]
        # "webhook_payload" => payload
      }

      if String.contains?(String.downcase(payload["Ad Set Name"]), "rent") do
        RawRentalPropertyPost.create(params, user_map)
      else
        RawResalePropertyPost.create(params, user_map)
      end
    end

    # notify
    channel = "paytm_webhook_dump"
    payload_message = payload |> Poison.encode!()
    ApplicationHelper.notify_on_slack("RawLead Facebook Webhook payload - #{payload_message}", channel)
  end

  def parse_phone_number(phone_number) do
    india_country_code = "+91"
    phone_number = phone_number |> to_string()
    len = phone_number |> String.length()
    last_ten_digits = String.slice(phone_number, (len - 10)..(len - 1)) |> String.replace("+", "")

    with {:ok, %{national_number: national_number, country_code: country_code} = result} <- ExPhoneNumber.parse(phone_number, nil) do
      is_valid_number = ExPhoneNumber.is_valid_number?(result)
      country_code = "+" <> Integer.to_string(country_code)
      phone = Integer.to_string(national_number)

      cond do
        country_code == india_country_code and is_valid_number ->
          {country_code, phone}

        is_valid_number ->
          {country_code, phone}

        true ->
          {india_country_code, last_ten_digits}
      end
    else
      {:error, _reason} ->
        {india_country_code, phone_number}

      false ->
        {india_country_code, phone_number}
    end
  end
end
