defmodule BnApis.Places.City do
  use Ecto.Schema
  alias BnApis.Repo
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Places.{City, Zone}

  schema "cities" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :name, :string
    field :feature_flags, :map
    field :sw_lat, :float
    field :sw_lng, :float
    field :ne_lat, :float
    field :ne_lng, :float

    has_many :zones, Zone
    timestamps()
  end

  @fields [:id, :uuid, :name, :feature_flags, :sw_lat, :sw_lng, :ne_lat, :ne_lng]
  @required_fields [:id, :uuid, :name]

  @seed_data [
    %{
      id: 1,
      uuid: "0bad2ed0-778d-11ec-9292-732788a779a4",
      name: "Mumbai",
      sw_lat: 18.890658,
      sw_lng: 72.693722,
      ne_lat: 19.740107,
      ne_lng: 73.128402,
      feature_flags: %{
        owner_assisted: true,
        matches: true,
        owners: true,
        subscriptions: true,
        invoice: true,
        cabs: true,
        transactions: true
      }
    },
    %{
      id: 37,
      uuid: "0baefc6a-778d-11ec-8394-b3395203ea6e",
      name: "Pune",
      sw_lat: 18.374792,
      sw_lng: 73.713276,
      ne_lat: 18.682089,
      ne_lng: 73.982441,
      feature_flags: %{
        owner_assisted: true,
        matches: true,
        owners: true,
        subscriptions: true,
        invoice: true,
        cabs: true,
        transactions: true
      }
    },
    %{
      id: 2,
      uuid: "c3d56abc-7865-11ec-b3bd-630ce155263b",
      name: "Bengaluru",
      sw_lat: 12.659352,
      sw_lng: 77.364510,
      ne_lat: 13.245546,
      ne_lng: 77.836923,
      feature_flags: %{
        owner_assisted: false,
        matches: true,
        owners: false,
        subscriptions: false,
        invoice: false,
        cabs: false,
        transactions: false
      }
    },
    %{
      id: 3,
      uuid: "104590aa-c7d2-11ec-a9fd-0694e8da7d78",
      name: "Gurugram",
      sw_lat: 12.659352,
      sw_lng: 77.364510,
      ne_lat: 13.245546,
      ne_lng: 77.836923,
      feature_flags: %{
        owner_assisted: false,
        matches: false,
        owners: false,
        subscriptions: false,
        invoice: false,
        cabs: false,
        transactions: false
      }
    }
  ]

  @doc false
  def changeset(city, attrs) do
    city
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:name)
  end

  def changeset(attrs) do
    %City{}
    |> changeset(attrs)
  end

  def seed_data() do
    @seed_data
  end

  def get_city_data(city) do
    %{
      "id" => city.id,
      "uuid" => city.uuid,
      "name" => city.name,
      "sw_lat" => city.sw_lat,
      "sw_lng" => city.sw_lng,
      "ne_lat" => city.ne_lat,
      "ne_lng" => city.ne_lng,
      "feature_flags" => %{
        "matches" => if(is_nil(city.feature_flags["matches"]), do: false, else: city.feature_flags["matches"]),
        "owners" => if(is_nil(city.feature_flags["owners"]), do: false, else: city.feature_flags["owners"]),
        "subscriptions" => if(is_nil(city.feature_flags["subscriptions"]), do: false, else: city.feature_flags["subscriptions"]),
        "invoice" => if(is_nil(city.feature_flags["invoice"]), do: false, else: city.feature_flags["invoice"]),
        "cabs" => if(is_nil(city.feature_flags["cabs"]), do: false, else: city.feature_flags["cabs"]),
        "transactions" => if(is_nil(city.feature_flags["transactions"]), do: false, else: city.feature_flags["transactions"]),
        "commercial" => if(is_nil(city.feature_flags["commercial"]), do: false, else: city.feature_flags["commercial"]),
        "residential" => if(is_nil(city.feature_flags["residential"]), do: false, else: city.feature_flags["residential"]),
        "home_loans" => if(is_nil(city.feature_flags["home_loans"]), do: false, else: city.feature_flags["home_loans"]),
        "booking_rewards" => Map.get(city.feature_flags, "booking_rewards", false)
      }
    }
  end

  def get_cities_list() do
    City
    |> Repo.all()
    |> Enum.map(fn city ->
      get_city_data(city)
    end)
  end

  def get_city_by_id(id), do: Repo.get_by(City, id: id)

  def update_city(params) do
    case params do
      %{
        "uuid" => uuid,
        "matches" => matches,
        "owners" => owners,
        "subscriptions" => subscriptions,
        "invoice" => invoice,
        "cabs" => cabs,
        "transactions" => transactions,
        "booking_rewards" => booking_rewards,
        "commercial" => commercial,
        "home_loans" => home_loans,
        "sw_lat" => sw_lat,
        "sw_lng" => sw_lng,
        "ne_lat" => ne_lat,
        "ne_lng" => ne_lng
      } ->
        case Repo.get_by(City, uuid: uuid) do
          nil ->
            {:error, "City not found"}

          city ->
            Repo.transaction(fn ->
              try do
                params = %{
                  "matches" => if(is_nil(matches), do: city.feature_flags["matches"], else: matches),
                  "owners" => if(is_nil(owners), do: city.feature_flags["owners"], else: owners),
                  "subscriptions" => if(is_nil(subscriptions), do: city.feature_flags["subscriptions"], else: subscriptions),
                  "invoice" => if(is_nil(invoice), do: city.feature_flags["invoice"], else: invoice),
                  "cabs" => if(is_nil(cabs), do: city.feature_flags["cabs"], else: cabs),
                  "transactions" => if(is_nil(transactions), do: city.feature_flags["transactions"], else: transactions),
                  "commercial" => if(is_nil(commercial), do: city.feature_flags["commercial"], else: commercial),
                  "home_loans" => if(is_nil(home_loans), do: city.feature_flags["home_loans"], else: home_loans),
                  "booking_rewards" =>
                    if(is_nil(booking_rewards),
                      do: Map.get(city.feature_flags, "booking_rewards", false),
                      else: booking_rewards
                    )
                }

                city
                |> changeset(%{
                  "feature_flags" => params,
                  "sw_lat" => sw_lat,
                  "sw_lng" => sw_lng,
                  "ne_lat" => ne_lat,
                  "ne_lng" => ne_lng
                })
                |> Repo.update!()

                get_city_data(city)
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def list_cities_with_owner_subscription() do
    from(c in City,
      where:
        fragment(~s|feature_flags @> '{"owners": true}'|) and
          fragment(~s|feature_flags @> '{"subscriptions": true}'|)
    )
    |> Repo.all()
    |> Enum.map(fn city ->
      %{"id" => city.id, "name" => city.name}
    end)
  end
end
