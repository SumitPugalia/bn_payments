defmodule BnApis.Helpers.Time do
  @day_time_tuples {{18, 30, 00}, {18, 29, 00}}

  @today "today"
  @this_week "this_week"
  @this_month "this_month"

  @owners_day_range_filters [
    %{id: 1, name: "All Time", key: "added_since_in_days", value: -1},
    %{id: 2, name: "Today", key: "added_since_in_days", value: 0},
    %{id: 3, name: "Last 1 week", key: "added_since_in_days", value: 7},
    %{id: 4, name: "Last 2 weeks", key: "added_since_in_days", value: 14},
    %{id: 5, name: "Last 3 weeks", key: "added_since_in_days", value: 21},
    %{id: 6, name: "Last 4 weeks", key: "added_since_in_days", value: -1}
  ]

  def today(), do: @today
  def this_week(), do: @this_week
  def this_month(), do: @this_month

  # ################################
  # TO ERL CONVERTION HELPER
  # ################################
  def epoch_to_erl(timestamp) do
    timestamp = if is_binary(timestamp), do: String.to_integer(timestamp), else: timestamp
    ms = rem(timestamp, 1000)
    timestamp = div(timestamp, 1000)
    basedate = :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
    {date, {h, m, s}} = (basedate + timestamp) |> :calendar.gregorian_seconds_to_datetime()
    # returning microsecond, required by ecto
    {date, {h, m, s, ms * 1000}}
  end

  # ################################
  # TO EPOCH CONVERTION HELPER
  # ################################

  def erl_to_epoch(erl_dt) do
    [erl_dt, micros] =
      case erl_dt do
        {date, {h, m, s, micros}} -> [{date, {h, m, s}}, micros]
        _ -> [erl_dt, 0]
      end

    timestamp = :calendar.datetime_to_gregorian_seconds(erl_dt)
    basedate = :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
    # returning in millis
    div((timestamp - basedate) * 1_000_000 + micros, 1_000)
  end

  def now_to_epoch do
    {mega, sec, micro_sec} = :os.timestamp()
    mega * 1000 * 1000 * 1000 + sec * 1000 + div(micro_sec, 1000)
  end

  def now_to_epoch_sec do
    now_to_epoch() |> div(1000)
  end

  def naive_to_epoch(nil), do: nil

  def naive_to_epoch(naive_dt) do
    erl_dt = NaiveDateTime.to_erl(naive_dt)
    erl_to_epoch(erl_dt)
  end

  def naive_to_epoch_in_sec(nil), do: nil

  def naive_to_epoch_in_sec(naive_dt) do
    div(naive_to_epoch(naive_dt), 1_000)
  end

  # ################################
  # TO NAIVE CONVERTION HELPER
  # ################################

  def erl_to_naive(erl_dt) do
    [erl_dt, micros] =
      case erl_dt do
        {date, {h, m, s, micros}} -> [{date, {h, m, s}}, micros]
        _ -> [erl_dt, 0]
      end

    NaiveDateTime.from_erl!(erl_dt, micros)
  end

  def epoch_to_naive(nil), do: nil

  def epoch_to_naive(timestamp) do
    timestamp = if is_binary(timestamp), do: String.to_integer(timestamp), else: timestamp
    timestamp |> epoch_to_erl |> erl_to_naive
  end

  # ################################
  # TO ECTO CONVERTION HELPER
  # ################################

  # Duration in seconds
  def expiration_time(duration) do
    now_to_epoch() + duration * 1000
  end

  # Duration in seconds
  def extend_time(epoch_time, duration) do
    epoch_time + duration * 1000
  end

  # Duration in seconds
  def minus_time(epoch_time, duration) do
    epoch_time - duration * 1000
  end

  def get_day_beginnning_and_end_time do
    current_datetime_tuple = NaiveDateTime.utc_now() |> NaiveDateTime.to_erl()
    date_tuple = current_datetime_tuple |> elem(0)
    {start_time_tuple, end_time_tuple} = @day_time_tuples
    {erl_to_naive({date_tuple, start_time_tuple}), erl_to_naive({date_tuple, end_time_tuple})}
  end

  def set_datetime(datetime, time_tuple) do
    datetime_tuple = datetime |> NaiveDateTime.to_erl() |> elem(0)
    erl_to_naive({datetime_tuple, time_tuple})
  end

  def set_expiry_time(days) when is_binary(days), do: set_expiry_time(String.to_integer(days))

  def set_expiry_time(days) do
    datetime_tuple = NaiveDateTime.add(NaiveDateTime.utc_now(), days * 24 * 60 * 60, :second) |> NaiveDateTime.to_erl()
    date_tuple = datetime_tuple |> elem(0)
    end_time_tuple = {18, 29, 59}
    erl_to_naive({date_tuple, end_time_tuple})
  end

  def get_start_of_day() do
    {date, {_h, _m, _s}} = NaiveDateTime.utc_now() |> NaiveDateTime.to_erl()
    start_of_day = {date, {0, 0, 0}}
    start_of_day |> erl_to_naive()
  end

  # Duration in seconds
  def get_difference_in_days_with_epoch(ep_dt1, ep_dt2 \\ DateTime.to_unix(DateTime.utc_now())) do
    ((ep_dt2 - ep_dt1) / (24 * 60 * 60)) |> round()
  end

  def get_difference_in_days(ecto_dt1, ecto_dt2 \\ NaiveDateTime.utc_now()) do
    ecto_dt1 = ecto_dt1 || NaiveDateTime.utc_now()
    (NaiveDateTime.diff(ecto_dt2, ecto_dt1) / 86400) |> round()
  end

  def get_time_range(time_range_query \\ "all") do
    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    end_time = today |> naive_to_epoch |> div(1000)

    case time_range_query do
      @today ->
        beginning_of_day = Timex.beginning_of_day(today) |> naive_to_epoch |> div(1000)
        {beginning_of_day, end_time}

      @this_week ->
        beginning_of_week = Timex.beginning_of_week(today) |> naive_to_epoch |> div(1000)
        {beginning_of_week, end_time}

      @this_month ->
        beginning_of_month = Timex.beginning_of_month(today) |> naive_to_epoch |> div(1000)
        {beginning_of_month, end_time}

      _ ->
        {0, end_time}
    end
  end

  def get_time_distance(date, timezone \\ "Asia/Kolkata") do
    beginning_of_today = Timex.now() |> Timex.Timezone.convert(timezone) |> Timex.beginning_of_day()
    beginning_of_date = date |> Timex.Timezone.convert(timezone) |> Timex.beginning_of_day()
    days = Timex.diff(beginning_of_today, beginning_of_date, :days)

    cond do
      days == 0 ->
        "today"

      days == 1 ->
        "1 day ago"

      days > 1 and days <= 7 ->
        "#{days} days ago"

      days > 7 and days <= 14 ->
        "2 weeks ago"

      days > 14 and days <= 21 ->
        "3 weeks ago"

      true ->
        "4 weeks ago"
    end
  end

  def get_formatted_datetime(%NaiveDateTime{} = datetime, format), do: datetime |> format_datetime(format)

  def get_formatted_datetime(datetime, format) when is_integer(datetime) do
    {:ok, datetime} = DateTime.from_unix(datetime)
    datetime |> format_datetime(format)
  end

  def get_current_month_limits_in_unix() do
    current_time = Timex.now()
    beginning_of_month = Timex.beginning_of_month(current_time)
    end_of_month = Timex.end_of_month(current_time)
    end_of_month_minus_one_day = Timex.shift(end_of_month, days: -1)
    end_of_month_five_pm = Timex.shift(end_of_month, hours: -7)

    {
      current_time |> DateTime.to_unix(),
      beginning_of_month |> DateTime.to_unix(),
      end_of_month_minus_one_day |> DateTime.to_unix(),
      end_of_month_five_pm |> DateTime.to_unix(),
      end_of_month |> DateTime.to_unix()
    }
  end

  def get_time_range_for_month(month, year) do
    {:ok, beginning_of_month} = year |> Timex.beginning_of_month(month) |> DateTime.new(Elixir.Time.new!(0, 0, 0))
    {:ok, end_of_month} = year |> Timex.end_of_month(month) |> DateTime.new(Elixir.Time.new!(0, 0, 0))
    {beginning_of_month |> DateTime.to_unix(), end_of_month |> DateTime.to_unix()}
  end

  def naive_second_to_millisecond(nil), do: nil

  def naive_second_to_millisecond(naive_timestamp) do
    naive_timestamp
    |> Timex.to_datetime()
    |> DateTime.to_unix(:millisecond)
    |> DateTime.from_unix!(:millisecond)
    |> DateTime.to_naive()
  end

  def get_start_time_in_unix(number_of_days_to_shift, timezone \\ "Asia/Kolkata") do
    Timex.now()
    |> Timex.Timezone.convert(timezone)
    |> Timex.shift(days: number_of_days_to_shift)
    |> Timex.beginning_of_day()
    |> DateTime.to_unix()
  end

  def get_end_time_in_unix(number_of_days_to_shift, timezone \\ "Asia/Kolkata") do
    Timex.now()
    |> Timex.Timezone.convert(timezone)
    |> Timex.shift(days: number_of_days_to_shift)
    |> Timex.end_of_day()
    |> DateTime.to_unix()
  end

  def get_max_naive_datetime(list_of_naive_dates) when length(list_of_naive_dates) > 0 do
    list_of_naive_dates
    |> Enum.sort({:desc, Date})
    |> hd()
  end

  def get_shifted_time(time_shift) do
    dt = Timex.now() |> DateTime.to_naive() |> Timex.shift(hours: time_shift) |> NaiveDateTime.truncate(:second)
    dt |> Timex.shift(minutes: -dt.minute) |> Timex.shift(seconds: -dt.second)
  end

  defp format_datetime(datetime, format) do
    datetime
    |> Timex.Timezone.convert("UTC")
    |> Timex.Timezone.convert("Asia/Kolkata")
    |> Timex.format!(format, :strftime)
  end

  # Input format - Timex
  # Output format - NaiveDatetime
  def get_start_time_by_timezone(time, timezone \\ "Asia/Kolkata") do
    time
    |> Timex.Timezone.convert(timezone)
    |> Timex.beginning_of_day()
    |> Timex.Timezone.convert("UTC")
    |> DateTime.to_naive()
  end

  # Input format - Timex
  # Output format - NaiveDatetime
  def get_end_time_by_timezone(time, timezone \\ "Asia/Kolkata") do
    time
    |> Timex.Timezone.convert(timezone)
    |> Timex.end_of_day()
    |> Timex.Timezone.convert("UTC")
    |> DateTime.to_naive()
  end

  @dsa_date_filters [
    %{id: 1, name: "All Time", key: "ALL_TIME", value: nil},
    %{id: 2, name: "Today", key: "TODAY", value: 0},
    %{id: 3, name: "Yesterday", key: "YESTERDAY", value: -1},
    %{id: 4, name: "Last 7 Days", key: "LAST_7_DAYS", value: -7},
    %{id: 5, name: "Last 30 Days", key: "LAST_30_DAYS", value: -30},
    %{id: 6, name: "Last 90 Days", key: "LAST_90_DAYS", value: -90},
    %{id: 7, name: "Last 365 Days", key: "LAST_365_DAYS", value: -365},
    %{id: 8, name: "Custom", key: "CUSTOM", value: nil}
  ]

  def get_owners_day_range_filters(), do: @owners_day_range_filters
  def get_dsa_date_filters(), do: @dsa_date_filters

  def get_date_range_by_id(nil), do: nil

  def get_date_range_by_id(id) do
    days_to_shift = @dsa_date_filters |> Enum.find(&(&1.id == id))

    cond do
      days_to_shift == nil -> nil
      days_to_shift.key == "YESTERDAY" -> [get_start_time_in_unix(-1), get_end_time_in_unix(-1)]
      days_to_shift.value == nil -> nil
      true -> [get_start_time_in_unix(days_to_shift.value), get_end_time_in_unix(0)]
    end
  end

  def get_beginning_of_the_day_for_unix(epoch_timestamp) do
    epoch_timestamp |> DateTime.from_unix!() |> Timex.beginning_of_day() |> naive_to_epoch |> div(1000)
  end

  def get_end_of_the_day_for_unix(epoch_timestamp) do
    epoch_timestamp |> DateTime.from_unix!() |> Timex.end_of_day() |> naive_to_epoch |> div(1000)
  end
end
