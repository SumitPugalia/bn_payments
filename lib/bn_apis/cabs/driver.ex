defmodule BnApis.Cabs.Driver do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Cabs.Operator
  alias BnApis.Cabs.Vehicle
  alias BnApis.Cabs.Driver
  alias BnApis.Repo
  alias BnApis.Places.City

  schema "cab_drivers" do
    field :name, :string
    field :phone_number, :string
    field :is_blacklisted, :boolean, default: false
    field :is_deleted, :boolean, default: false
    belongs_to(:cab_operator, Operator)
    belongs_to(:city, City)

    timestamps()
  end

  @required [:name, :phone_number, :cab_operator_id, :city_id]
  @optional [:is_blacklisted, :is_deleted]

  @doc false
  def changeset(driver, attrs) do
    driver
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:phone_number,
      name: :cab_drivers_unique_constraint_on_not_is_deleted,
      message: "An active driver with same phone number exists"
    )
    |> foreign_key_constraint(:cab_operator_id)
    |> validate_driver_assigned()
  end

  def create!(params) do
    %Driver{}
    |> Driver.changeset(params)
    |> Repo.insert!()
  end

  def update!(driver, params) do
    driver |> Driver.changeset(params) |> Repo.update!()
  end

  def check_driver(phone_number) do
    Driver
    |> where([d], (is_nil(d.is_deleted) or d.is_deleted == false) and d.phone_number == ^phone_number)
    |> Repo.one()
  end

  def get_data(nil) do
    %{}
  end

  def get_data(driver) do
    driver = driver |> Repo.preload([:cab_operator, :city])

    %{
      "id" => driver.id,
      "name" => driver.name,
      "phone_number" => driver.phone_number,
      "is_blacklisted" => driver.is_blacklisted,
      "operator" => Operator.get_data(driver.cab_operator),
      "created_at" => driver.inserted_at,
      "is_deleted" => driver.is_deleted,
      "city" => driver.city.name,
      "city_id" => driver.city.id
    }
  end

  defp validate_driver_assigned(changeset) do
    case changeset.valid? do
      true ->
        is_deleted = get_field(changeset, :is_deleted)
        id = get_field(changeset, :id)

        if not is_nil(id) and is_deleted == true and not is_nil(changeset.changes[:is_deleted]) do
          assignedVehicle = Vehicle |> where([v], v.is_deleted != true and v.cab_driver_id == ^id) |> Repo.one()

          if not is_nil(assignedVehicle) do
            add_error(
              changeset,
              :is_deleted,
              "Driver cannot be marked as deleted as already assigned to #{assignedVehicle.vehicle_number}"
            )
          else
            changeset
          end
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  def get_drivers_list(query, page_no, city_id, hide_blacklisted) do
    limit = 100
    offset = (page_no - 1) * limit
    drivers = Driver

    drivers =
      if !is_nil(query) && is_binary(query) && String.trim(query) != "" do
        formatted_query = "%#{String.downcase(String.trim(query))}%"

        drivers
        |> where(
          [d],
          fragment("LOWER(?) LIKE ?", d.name, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", d.phone_number, ^formatted_query)
        )
      else
        drivers
      end

    drivers =
      if is_nil(hide_blacklisted) or hide_blacklisted == 'true' do
        # assigned_drivers =  Vehicle |> where([v], (is_nil(v.is_deleted) or v.is_deleted == false) and not is_nil(v.cab_driver_id)) |> Repo.all() |> Enum.map(& &1.cab_driver_id)
        # drivers |> where([d], d.id not in ^assigned_drivers)
        drivers |> where([d], d.is_blacklisted == false)
      else
        drivers
      end

    drivers =
      if !is_nil(city_id) do
        drivers |> where([d], d.city_id == ^city_id)
      else
        drivers
      end

    drivers = drivers |> where([d], is_nil(d.is_deleted) or d.is_deleted == false)

    drivers =
      drivers
      |> offset(^offset)
      |> limit(^limit)
      |> order_by([d], desc: d.inserted_at)
      |> Repo.all()
      |> Repo.preload(:cab_operator)

    drivers_details =
      drivers
      |> Enum.map(fn driver ->
        Driver.get_data(driver)
      end)

    %{
      "drivers" => drivers_details,
      "next_page_exists" => Enum.count(drivers) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end
end
