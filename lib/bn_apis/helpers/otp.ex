defmodule BnApis.Helpers.Otp do
  alias BnApis.Helpers.Redis
  alias BnApis.Accounts.ProfileType
  alias BnApis.Helpers.ApplicationHelper

  # in seconds
  @otp_life 1800
  @access_otp_life 86400
  @otp_request_limit_life 3600

  @retry_limit 50
  @otp_length 6
  @otp_request_limit 50

  @redis_prefix "PVT_"

  @redis_signup_prefix "SIGNUP_"
  # 1 day in seconds
  @signup_token_life 24 * 60 * 60

  @profile_type_id ProfileType.broker().id

  @doc """
    1. will send the same otp if it already exist
    2. else will generate the new otp
  """
  def generate_otp_tokens(phone_number, profile_type_id \\ @profile_type_id) do
    key = key(phone_number, profile_type_id)

    otp_request_count_key = otp_request_count_key(phone_number, profile_type_id)

    %{otp: stored_otp, retry_count: _retry_count} = fetch_otp(key)

    cond do
      is_nil(stored_otp) ->
        check_limit_and_generate(phone_number, profile_type_id)

      stored_otp ->
        %{otp_request_count: stored_otp_request_count} = fetch_value(otp_request_count_key)

        if stored_otp_request_count > @otp_request_limit do
          {:otp_error,
           %{
             otp_requested_count: stored_otp_request_count,
             max_count_allowed: @otp_request_limit,
             message: "Max Request count reached... try again after sometime"
           }}
        else
          # reset_otp_expiry(key)
          {:ok,
           %{
             otp: stored_otp,
             otp_requested_count: stored_otp_request_count,
             max_count_allowed: @otp_request_limit
           }}
        end

      true ->
        {:error, "Something is not right with your phone_number, check and try again"}
    end
  end

  defp check_limit_and_generate(phone_number, profile_type_id) do
    key = key(phone_number, profile_type_id)
    otp_request_count_key = otp_request_count_key(phone_number, profile_type_id)

    # delete(key) # Uncomment for testing
    # delete(otp_request_count_key) # comment this when you require request limit

    case Redis.q(["HGET", otp_request_count_key, "otp_request_count"]) do
      {:ok, nil} ->
        set_otp_request_count(otp_request_count_key)
        delete(key)

        {:ok,
         %{otp_requested_count: 1, max_count_allowed: @otp_request_limit}
         |> Map.merge(generate_otp(key))}

      {:ok, _otp_request_count} ->
        %{otp_request_count: stored_otp_request_count} = fetch_value(otp_request_count_key)

        delete(key)

        {:ok,
         %{
           otp_requested_count: stored_otp_request_count,
           max_count_allowed: @otp_request_limit
         }
         |> Map.merge(generate_otp(key))}
    end
  end

  def verify_otp(phone_number, profile_type_id, otp) do
    key = key(phone_number, profile_type_id)
    %{otp: stored_otp, retry_count: retry_count} = fetch_otp(key)

    cond do
      stored_otp == otp ->
        delete(key)
        {:ok}

      stored_otp && retry_count < @retry_limit ->
        {:otp_error, %{retries_left: @retry_limit - retry_count, message: "Incorrect OTP"}}

      true ->
        delete(key)

        {:otp_error, %{retries_left: 0, message: "OTP verification failed... try again"}}
    end
  end

  def clean_otp_request_count(nil, _profile_type_id) do
    {:error, 0}
  end

  def clean_otp_request_count(phone_number, profile_type_id) do
    otp_request_count_key(phone_number, profile_type_id) |> delete()
  end

  def generate_signup_token(phone_number, country_code, profile_type_id \\ @profile_type_id) do
    {:ok, store_signup_token(phone_number, country_code, profile_type_id)}
  end

  def verify_signup_token(signup_token, _profile_type_id) do
    key = @redis_signup_prefix <> signup_token

    case Redis.q(["HMGET", key, "phone", "country_code"]) do
      {:ok, [nil, _]} ->
        channel = ApplicationHelper.get_slack_channel()

        Task.start_link(fn ->
          ApplicationHelper.notify_on_slack(
            "Issue: Signup Token - #{signup_token} not found on Redis",
            channel
          )
        end)

        {:error, "Invalid signup_token!"}

      {:ok, [phone_number, nil]} ->
        {:ok, phone_number, "+91"}

      {:ok, [phone_number, country_code]} ->
        {:ok, phone_number, country_code}
    end
  end

  def delete_signup_token(signup_token) do
    key = @redis_signup_prefix <> signup_token
    delete(key)
  end

  @doc """
    Method for testing OTP verification flow
    Shoiud not be used in other environments
  """
  def get_otp(phone_number, profile_type_id) do
    key(phone_number, profile_type_id)
    |> fetch_otp(false)
  end

  def get_otp_life() do
    (@otp_life / 60) |> round()
  end

  def get_otp(otp_length) do
    :rand.uniform(9 * min_num(otp_length)) + max_num(otp_length - 1)
  end

  def generate_otp(key) do
    otp = get_otp(@otp_length)

    otp =
      if key == "pvt_9999999999_4" || key == "pvt_9999999999_1" ||
           key == "pvt_8888812345_4" || key == "pvt_8888812345_2" || key == "pvt_8888812345_1" do
        "999999"
      else
        otp
      end

    Redis.q(["HSET", key, "otp", otp])
    Redis.q(["HSET", key, "retry_count", 0])
    Redis.q(["EXPIRE", key, @otp_life])
    %{otp: otp}
  end

  defp generate_access_otp(key) do
    otp = get_otp(@otp_length)

    otp =
      if key == "pvt_9999999999_4" || key == "pvt_9999999999_1" do
        "999999"
      else
        otp
      end

    Redis.q(["HSET", key, "otp", otp])
    Redis.q(["HSET", key, "retry_count", 0])
    Redis.q(["EXPIRE", key, @access_otp_life])
    %{otp: otp}
  end

  def get_access_otp(phone_number, profile_type_id) do
    key = key(phone_number, profile_type_id)
    %{otp: stored_otp, retry_count: _retry_count} = fetch_otp(key)

    cond do
      is_nil(stored_otp) ->
        generate_access_otp(key)

      true ->
        %{otp: stored_otp}
    end
  end

  defp set_otp_request_count(key) do
    Redis.q(["HSET", key, "otp_request_count", 1])
    Redis.q(["EXPIRE", key, @otp_request_limit_life])
  end

  defp max_num(1), do: 9

  defp max_num(digits) when digits > 1 do
    String.to_integer("9" <> :erlang.integer_to_binary(max_num(digits - 1)))
  end

  defp min_num(digits) when digits > 0 do
    :math.pow(10, digits - 1) |> round
  end

  # @doc """
  #   increment_retry_count = False will only be used in test mode and will be called from get_otp method
  # """
  def fetch_otp(key, increment_retry_count \\ true) do
    {:ok, stored_otp} = Redis.q(["HGET", key, "otp"])

    {:ok, retry_count} =
      if increment_retry_count do
        Redis.q(["HINCRBY", key, "retry_count", 1])
      else
        Redis.q(["HGET", key, "retry_count"])
      end

    %{
      otp: stored_otp,
      retry_count: retry_count
    }
  end

  defp fetch_value(key, increment_count \\ true) do
    {:ok, otp_request_count} =
      if increment_count do
        Redis.q(["HINCRBY", key, "otp_request_count", 1])
      else
        Redis.q(["HGET", key, "otp_request_count"])
      end

    %{
      otp_request_count: otp_request_count
    }
  end

  # defp reset_otp_expiry(key) do
  #   Redis.q(["EXPIRE", key, @otp_life])
  # end

  defp store_signup_token(phone_number, country_code, profile_type_id) do
    signup_token = SecureRandom.urlsafe_base64(32)
    key = @redis_signup_prefix <> signup_token
    Redis.q(["HSET", key, "profile_type_id", profile_type_id])
    Redis.q(["HSET", key, "phone", phone_number])
    Redis.q(["HSET", key, "country_code", country_code])
    Redis.q(["EXPIRE", key, @signup_token_life])
    signup_token
  end

  defp key(phone_number, profile_type_id) do
    "#{@redis_prefix}#{phone_number}_#{profile_type_id}" |> String.downcase()
  end

  defp otp_request_count_key(phone_number, profile_type_id) do
    "#{@redis_prefix}#{phone_number}_#{profile_type_id}_otp_request_count"
    |> String.downcase()
  end

  # Clean existing otps if any
  def delete(key) do
    Redis.q(["DEL", key])
  end
end
