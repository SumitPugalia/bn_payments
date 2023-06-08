defmodule BnApis.Helpers.Utils do
  alias BnApis.Helpers.{Time, NumbersToWords}
  alias BnApis.Accounts.{WhitelistedBrokerInfo, Invite, WhitelistedNumber, Credential, EmployeeCredential}
  alias BnApis.Helpers.ApplicationHelper

  @broker "Broker"
  @employee "Employee"
  @whitelisted_number "WhitelistedNumber"
  @whitelisted_broker "WhitelistedBroker"
  @invited_broker "InvitedBroker"

  def format_float(val) do
    if is_float(val) do
      trunc(val)
    else
      val
    end
  end

  def float(value) do
    case is_integer(value) do
      true ->
        value

      false ->
        {a, b} = Float.to_string(value) |> Integer.parse()
        "#{a}" <> String.slice(b, 0, 3)
    end
  end

  def float_with_digits(value, decimal_count) do
    case is_integer(value) do
      true ->
        value

      false ->
        {a, b} = Float.to_string(value) |> Integer.parse()
        "#{a}" <> String.slice(b, 0, decimal_count + 1)
    end
  end

  def format_money_new(rupees) when is_nil(rupees), do: "-"
  def format_money_new(rupees) when is_binary(rupees), do: format_money(rupees |> String.to_integer())

  def format_money_new(rupees) when rupees < 100_0 do
    rupee_string = float(rupees)
    "#{rupee_string}"
  end

  def format_money_new(rupees) when rupees < 100_000 do
    rupee_string = (rupees / :math.pow(10, 3)) |> float()
    "#{rupee_string} K"
  end

  def format_money_new(rupees) when rupees < 10_000_000 do
    rupee_string = (rupees / :math.pow(10, 5)) |> float()
    "#{rupee_string} L"
  end

  def format_money_new(rupees) do
    rupee_string = (rupees / :math.pow(10, 7)) |> float()
    "#{rupee_string} Cr"
  end

  def format_money(rupees) when is_nil(rupees), do: "-"
  def format_money(rupees) when is_binary(rupees), do: format_money(rupees |> String.to_integer())

  def format_money(rupees) when rupees < 100_0 do
    rupee_string =
      if is_float(rupees),
        do: rupees |> :erlang.float_to_binary([:compact, {:decimals, 2}]) |> String.trim_trailing(".0"),
        else: rupees

    "#{rupee_string}"
  end

  def format_money(rupees) when rupees < 100_000 do
    rupee_string = (rupees / :math.pow(10, 3)) |> :erlang.float_to_binary([:compact, {:decimals, 2}]) |> String.trim_trailing(".0")

    "#{rupee_string} K"
  end

  def format_money(rupees) when rupees < 10_000_000 do
    rupee_string = (rupees / :math.pow(10, 5)) |> :erlang.float_to_binary([:compact, {:decimals, 2}]) |> String.trim_trailing(".0")

    "#{rupee_string} L"
  end

  def format_money(rupees) do
    rupee_string = (rupees / :math.pow(10, 7)) |> :erlang.float_to_binary([:compact, {:decimals, 2}]) |> String.trim_trailing(".0")

    "#{rupee_string} Cr"
  end

  def date_in_days(date) do
    if is_nil(date) do
      nil
    else
      today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.beginning_of_day() |> DateTime.to_unix()

      if date > today do
        ceil((date - today) / (24 * 60 * 60))
      else
        nil
      end
    end
  end

  def add_and_update_unix_key(data, key) do
    data
    |> Map.put(:"#{key}_unix", data[key] |> Time.naive_to_epoch_in_sec())
    |> Map.put(key, Time.naive_second_to_millisecond(data[key]))
  end

  def get_user_map(logged_in_user) do
    %{
      user_id: logged_in_user[:user_id],
      user_type: logged_in_user[:user_type]
    }
  end

  def get_whitelisted_or_invited_broker_user_map(phone_number, country_code) do
    credential = Credential.fetch_credential(phone_number, country_code)
    whitelisted_number = WhitelistedNumber.fetch_whitelisted_number(phone_number, country_code)
    whitelisted_broker = WhitelistedBrokerInfo.fetch_whitelisted_number(phone_number, country_code)
    invited_broker = Invite.fetch_invited_broker(phone_number, country_code)

    cond do
      not is_nil(credential) ->
        %{
          user_id: credential.id,
          user_type: @broker
        }

      not is_nil(whitelisted_number) ->
        %{
          user_id: whitelisted_number.id,
          user_type: @whitelisted_number
        }

      not is_nil(whitelisted_broker) ->
        %{
          user_id: whitelisted_broker.id,
          user_type: @whitelisted_broker
        }

      not is_nil(invited_broker) ->
        %{
          user_id: invited_broker.id,
          user_type: @invited_broker
        }
    end
  end

  def tax_breakup(price) do
    taxable_value = price / 1.18
    cgst_value = taxable_value * 0.09
    sgst_value = taxable_value * 0.09
    total_tax = cgst_value + sgst_value
    price_in_words = ((price / 1) |> float_in_words()) <> " rupees"
    total_tax_in_words = (total_tax |> float_in_words()) <> " rupees"

    price = (price / 1) |> float_roundoff()
    taxable_value = taxable_value |> float_roundoff()
    cgst_value = cgst_value |> float_roundoff()
    sgst_value = sgst_value |> float_roundoff()
    total_tax = total_tax |> float_roundoff()
    {price, price_in_words, taxable_value, cgst_value, sgst_value, total_tax, total_tax_in_words}
  end

  def float_roundoff(value) do
    value
    |> Decimal.from_float()
    |> Decimal.round(2)
    |> Decimal.to_string()
  end

  def float_in_words(value) do
    value
    |> ceil()
    |> NumbersToWords.parse()
    |> String.capitalize()
  end

  def get_user_map_with_employee_cred(id), do: %{user_id: id, user_type: "employee"}

  def to_lowercase(search_text) when is_binary(search_text), do: search_text |> String.trim() |> String.downcase()
  def get_modified_search_text(search_text), do: "%" <> to_lowercase(search_text) <> "%"
  def parse_boolean_param(attr, string_default_value \\ true)
  def parse_boolean_param(nil, string_default_value), do: string_default_value

  def parse_boolean_param(attr, _string_default_value) when is_binary(attr),
    do: String.trim(attr) |> String.downcase() == "true"

  def parse_boolean_param(attr, _string_default_value) when is_boolean(attr), do: attr

  def parse_to_integer(attr, string_default_value \\ nil)
  def parse_to_integer(nil, string_default_value), do: string_default_value
  def parse_to_integer(attr, _string_default_value) when is_binary(attr) and attr != "", do: String.to_integer(attr)
  def parse_to_integer(attr, _string_default_value) when is_binary(attr) and attr == "", do: nil
  def parse_to_integer(attr, _string_default_value) when is_integer(attr), do: attr

  def get_month_name_by_month_number(1), do: "January"
  def get_month_name_by_month_number(2), do: "February"
  def get_month_name_by_month_number(3), do: "March"
  def get_month_name_by_month_number(4), do: "April"
  def get_month_name_by_month_number(5), do: "May"
  def get_month_name_by_month_number(6), do: "June"
  def get_month_name_by_month_number(7), do: "July"
  def get_month_name_by_month_number(8), do: "August"
  def get_month_name_by_month_number(9), do: "September"
  def get_month_name_by_month_number(10), do: "October"
  def get_month_name_by_month_number(11), do: "November"
  def get_month_name_by_month_number(12), do: "December"

  def create_geopoint(_params = %{"latitude" => latitude, "longitude" => longitude}) do
    coordinates = get_coordinates(latitude, longitude)
    %Geo.Point{coordinates: coordinates, srid: 4326}
  end

  defp get_coordinates(latitude, longitude) do
    {latitude, _} =
      if latitude |> is_binary(),
        do: latitude |> ApplicationHelper.strip_chars(", ") |> Float.parse(),
        else: {latitude, ""}

    {longitude, _} =
      if longitude |> is_binary(),
        do: longitude |> ApplicationHelper.strip_chars(", ") |> Float.parse(),
        else: {longitude, ""}

    {latitude, longitude}
  end

  def geo_location_to_lat_lng(entity_map = %{location: location}) do
    [latitude, longitude] = (location |> Geo.JSON.encode!())["coordinates"]

    entity_map
    |> Map.merge(%{
      latitude: latitude,
      longitude: longitude
    })
    |> Map.delete(:location)
  end

  def get_employee_user_map(%{"phone_number" => phone_number, "country_code" => country_code}) do
    user = EmployeeCredential.fetch_employee_credential(phone_number, country_code)

    %{user_id: user.id, user_type: @employee}
  end

  def get_active_fcm_credential(credentials) do
    case Enum.find(credentials, fn c -> c.active == true and not is_nil(c.fcm_id) end) do
      nil -> nil
      cred -> cred
    end
  end

  def parse_url(nil), do: nil

  def parse_url(string) do
    if Regex.match?(~r/^http.*/, string), do: string, else: nil
  end

  def validate_pan(pan) do
    pan = String.upcase(pan)
    String.match?(pan, ~r/^[A-Z]{5}[0-9]{4}[A-Z]{1}$/)
  end
end
