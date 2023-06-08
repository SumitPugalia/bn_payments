defmodule BnApis.Cabs.BookingSlot do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Cabs.BookingSlot
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Places.City
  alias BnApis.Helpers.Time

  schema "cab_booking_slots" do
    field :slot_date, :naive_datetime
    field :start_date_time, :naive_datetime
    field :end_date_time, :naive_datetime
    field :booking_start_time, :naive_datetime
    field :booking_end_time, :naive_datetime
    field :user_id, :integer
    field :is_slot_start_open, :boolean, default: true
    belongs_to(:city, City)
    timestamps()
  end

  @required [:slot_date, :end_date_time, :start_date_time, :user_id, :is_slot_start_open, :city_id]
  @optional [:booking_start_time, :booking_end_time]

  @doc false
  def changeset(booking_slot, attrs) do
    booking_slot
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end

  def create!(params) do
    %BookingSlot{}
    |> BookingSlot.changeset(params)
    |> Repo.insert!()
  end

  def update!(booking_slot, params) do
    booking_slot
    |> BookingSlot.changeset(params)
    |> Repo.update!()
  end

  def get_slot_data(slot) do
    slot_data =
      if not is_nil(slot) do
        user = Repo.get_by(EmployeeCredential, id: slot.user_id)
        slot_date = slot.slot_date |> Timex.Timezone.convert("Asia/Kolkata")
        beginning_of_day = Timex.beginning_of_day(slot_date)

        %{
          "id" => slot.id,
          "slot_date" => slot.slot_date |> Time.naive_to_epoch_in_sec(),
          "start_date_time" => if(not is_nil(slot.start_date_time), do: slot.start_date_time |> Time.naive_to_epoch_in_sec(), else: nil),
          "end_date_time" => slot.end_date_time |> Time.naive_to_epoch_in_sec(),
          "is_slot_start_open" => slot.is_slot_start_open,
          "booking_start_time" =>
            if(not is_nil(slot.booking_start_time),
              do: slot.booking_start_time |> Time.naive_to_epoch_in_sec(),
              else: beginning_of_day |> Timex.shift(hours: 9) |> DateTime.to_unix()
            ),
          "booking_end_time" =>
            if(not is_nil(slot.booking_end_time),
              do: slot.booking_end_time |> Time.naive_to_epoch_in_sec(),
              else: beginning_of_day |> Timex.shift(hours: 15) |> DateTime.to_unix()
            ),
          "city_id" => slot.city_id,
          "user_details" => %{
            "id" => user.id,
            "name" => user.name,
            "phone_number" => user.phone_number
          },
          "inserted_at" => slot.inserted_at |> Time.naive_to_epoch_in_sec(),
          "updated_at" => slot.updated_at |> Time.naive_to_epoch_in_sec()
        }
      else
        nil
      end

    slot_data
  end

  def get_booking_slot_list(city_id) do
    to_be_added_days = [0, 1, 7, 8, 14, 15, 21, 22, 28, 29, 35, 36, 42, 43]
    today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    beginning_of_day = Timex.beginning_of_day(today)
    this_sun = Timex.end_of_week(beginning_of_day) |> Timex.beginning_of_day()
    this_sat = Timex.shift(this_sun, days: -1)

    future_slots =
      to_be_added_days
      |> Enum.map(fn day_to_be_added ->
        slot_date =
          Timex.shift(this_sat, days: day_to_be_added)
          |> DateTime.to_naive()
          |> Timex.Timezone.convert("Asia/Kolkata")
          |> Timex.Timezone.convert("GMT")

        get_slot_details(slot_date, city_id)
      end)

    %{
      "booking_slots" => future_slots
    }
  end

  def get_default_slot_data(slot_date, city_id \\ 1) do
    slot_date = slot_date |> Timex.Timezone.convert("Asia/Kolkata")
    beginning_of_day = Timex.beginning_of_day(slot_date)
    one_day_before = Timex.shift(beginning_of_day, days: -1)
    end_time_of_the_day = Timex.shift(one_day_before, hours: 16)
    start_time_of_the_day = Timex.beginning_of_week(slot_date)

    %{
      "slot_date" => slot_date |> DateTime.to_unix(),
      "end_date_time" => end_time_of_the_day |> DateTime.to_unix(),
      "start_date_time" => start_time_of_the_day |> DateTime.to_unix(),
      "booking_start_time" => beginning_of_day |> Timex.shift(hours: 9) |> DateTime.to_unix(),
      "booking_end_time" => beginning_of_day |> Timex.shift(hours: 15) |> DateTime.to_unix(),
      "is_slot_start_open" => true,
      "city_id" => city_id
    }
  end

  def get_slot_details(slot_date, city_id \\ 1) do
    slot =
      BookingSlot
      |> where([bs], bs.slot_date == ^slot_date and bs.city_id == ^city_id)
      |> preload([:city])
      |> Repo.one()

    if not is_nil(slot) do
      get_slot_data(slot)
    else
      get_default_slot_data(slot_date, city_id)
    end
  end
end
