defmodule BnApis.Workers.Dubailand.ScrapeBroker do
  @moduledoc """
  Worker one time scrape new brokers from dubailand
  """
  require Logger

  alias BnApis.Schemas.ScrapperInfo
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Organizations.Organization
  alias BnApis.Organizations.Broker
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Repo

  @page_size_int 100
  @base_url "https://gateway.dubailand.gov.ae/open-data/"
  @scrapper_name "scrap_broker_dubailand"
  @header ~w(BROKER_EN BROKER_ID BROKER_NUMBER PHONE REAL_ESTATE_BROKER_ID REAL_ESTATE_EN REAL_ESTATE_ID REAL_ESTATE_NUMBER error)

  def start_scrap() do
    @scrapper_name
    |> ScrapperInfo.get_scrap_info()
    |> maybe_set_default_values()
    |> case do
      {:ok, %{offset: offset} = scrapper} ->
        build_post_params(offset)
        |> send_post_request()
        |> parse_transaction_response()
        |> populate_brokers_into_db()
        |> submit_success_report()
        |> write_status_to_db(scrapper)
        |> maybe_goto_next_page()
    end
  end

  defp write_status_to_db(%{"RN" => last_entry} = last_element, scrapper) do
    date_diff = Date.compare(Date.utc_today(), scrapper.date)

    if (date_diff == :eq and last_entry > String.to_integer(scrapper.offset)) or
         date_diff == :gt do
      ScrapperInfo.update_scrape_info(scrapper, %{offset: Integer.to_string(last_entry), date: Date.utc_today()})
    end

    last_element
  end

  defp submit_success_report({failed_list, last_element}) do
    write_failed_entries_to_csv(failed_list)
    send_slack_notification(length(failed_list))

    last_element
  end

  defp send_slack_notification(failed_count) do
    channel =
      :bn_apis
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:slack_channel)

    text = "From total of #{@page_size_int} entries, #{@page_size_int - failed_count} new brokers added and #{failed_count} failed"

    if channel == nil do
      :ok
    else
      ApplicationHelper.notify_on_slack(text, channel)
    end
  end

  defp write_failed_entries_to_csv([]), do: :ok

  defp write_failed_entries_to_csv(failed_list) do
    try do
      failed_list
      |> Stream.map(&Map.take(&1, @header))
      |> CSV.encode(headers: @header)
      |> Enum.into(File.stream!(generate_filename()))

      :ok
    rescue
      _ ->
        Logger.error("Failed to write to CSV")
    end
  end

  defp maybe_goto_next_page(%{"RN" => current, "TOTAL" => total}) when current < total do
    start_scrap()
  end

  defp maybe_goto_next_page(_), do: :ok

  defp populate_brokers_into_db(list) do
    user_map = %{
      user_id: -3000,
      user_type: "broker"
    }

    rejected_entries =
      Enum.reduce(list, [], fn params, acc ->
        {status, data} =
          case prepare_whitelist_params(params) do
            {:error, _reason} = error -> error
            whitelist_params -> Broker.whitelist_broker(whitelist_params, nil, user_map, true)
          end

        if status == :error, do: [Map.merge(params, %{"error" => inspect(data)}) | acc], else: acc
      end)

    {rejected_entries, List.last(list)}
  end

  defp build_post_params(offset),
    do: %{
      "P_GENDER" => "",
      "P_TAKE" => Integer.to_string(@page_size_int),
      "P_SKIP" => offset,
      "P_SORT" => "BROKER_ID_ASC"
    }

  defp send_post_request(payload), do: ExternalApiHelper.perform(:post, @base_url <> "brokers", payload)

  defp parse_transaction_response({200, response}),
    do: response["response"]["result"] || []

  defp maybe_set_default_values(nil) do
    ScrapperInfo.insert(%{offset: "0", date: Date.utc_today(), name: @scrapper_name})
  end

  defp maybe_set_default_values(value), do: {:ok, value}

  defp get_real_estate_id(id) do
    case Repo.get_by(Organization, real_estate_id: id) do
      nil -> nil
      %Organization{uuid: org_id} -> org_id
    end
  end

  defp prepare_whitelist_params(params) do
    case parse_phone_number(params["PHONE"]) do
      {:ok, phone_number, country_code} ->
        %{
          "assign_to" => nil,
          "broker_name" => params["BROKER_EN"],
          "firm_address" => nil,
          "organization_name" => params["REAL_ESTATE_EN"],
          "phone_number" => phone_number,
          "place_id" => nil,
          "polygon_uuid" => nil,
          "organization_uuid" => get_real_estate_id(params["REAL_ESTATE_ID"]),
          "real_estate_id" => params["REAL_ESTATE_ID"],
          "country_code" => country_code,
          "is_match_enabled" => true
        }

      {:error, _} = error ->
        error
    end
  end

  def parse_phone_number(nil), do: {:error, "phone number doesn't exist"}

  def parse_phone_number(phone_number) do
    sanitize_number(phone_number, "")
    |> validate_phone_number()
  end

  defp sanitize_number(<<>>, acc), do: acc

  defp sanitize_number(<<c::utf8, rest::binary>>, acc) when c >= 48 and c < 58,
    do: sanitize_number(rest, acc <> List.to_string([c]))

  defp sanitize_number(<<_c::utf8, rest::binary>>, acc),
    do: sanitize_number(rest, acc)

  def validate_phone_number(phone_number) do
    with {:ok, %{national_number: national_number, country_code: country_code} = result} <-
           ExPhoneNumber.parse(phone_number, "AE"),
         true <- ExPhoneNumber.is_valid_number?(result) do
      {:ok, Integer.to_string(national_number), "+" <> Integer.to_string(country_code)}
    else
      false ->
        {:error, "invalid number"}

      {:error, _reason} = error ->
        error
    end
  end

  defp generate_filename do
    Integer.to_string(Timex.to_gregorian_microseconds(DateTime.utc_now())) <> @scrapper_name <> "_errors.csv"
  end
end
