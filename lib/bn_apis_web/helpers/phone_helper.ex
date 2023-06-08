defmodule BnApisWeb.Helpers.PhoneHelper do
  @moduledoc """
  Helper module to parse phone number
  """
  alias BnApisWeb.Helpers.CountryCodeConstant

  @type string_map :: %{required(String.t()) => String.t()}

  @country_code_map CountryCodeConstant.directory()

  @spec parse_phone_number(string_map()) :: {:ok, String.t(), String.t()} | {:error, String.t()}
  def parse_phone_number(%{"phone_number" => phone_number} = params),
    do:
      params
      |> get_country_code()
      |> parse_phone_number(phone_number)

  @spec parse_phone_number(country_code :: String.t(), phone_number :: String.t()) ::
          {:ok, phone_number :: String.t(), country_code :: String.t()} | {:error, String.t()}
  def parse_phone_number(country_code, phone_number) do
    with {:ok, %{national_number: national_number} = result} <-
           ExPhoneNumber.parse(phone_number, @country_code_map[country_code]),
         true <- ExPhoneNumber.is_valid_number?(result) do
      {:ok, Integer.to_string(national_number), country_code}
    else
      false ->
        {:error, "Something is not right with your phone_number, check and try again"}

      {:error, _reason} = error ->
        error
    end
  end

  def append_country_code(phone_number, country_code), do: "#{country_code}#{phone_number}"

  defp get_country_code(%{"country_code" => nil}), do: "+91"
  defp get_country_code(%{"country_code" => "+" <> _ = country_code}), do: country_code
  defp get_country_code(_), do: "+91"

  def maybe_remove_country_code(phone_number) do
    phone_number_length = phone_number |> String.length()

    if phone_number_length > 10 do
      String.slice(phone_number, -10, 10)
    else
      phone_number
    end
  end

  # changes 917769941486 to +91-7769941486
  def structure_12_digit_number(phone_number) do
    if String.length(phone_number) > 10 do
      last_10_digits = String.slice(phone_number, -10, 10)
      first_2_digits = String.slice(phone_number, 0, 2)
      "+#{first_2_digits}-#{last_10_digits}"
    end
  end
end
