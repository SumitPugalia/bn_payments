defmodule BnApis.Homeloan.Country do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Homeloan.Country

  schema "countries" do
    field(:name, :string)
    field(:country_code, :string)
    field(:url_name, :string)
    field(:is_operational, :boolean, default: false)
    field(:phone_validation_regex, :string)
    field(:order, :integer)
    timestamps()
  end

  @required [
    :name,
    :country_code,
    :url_name,
    :is_operational,
    :phone_validation_regex,
    :order
  ]
  @optional []

  @seed_data [
    %{
      name: "India",
      country_code: "+91",
      url_name: "IN",
      is_operational: true,
      phone_validation_regex: "^[6-9]\\d{9}$",
      order: 1
    }
  ]

  @doc false
  def changeset(country, attrs) do
    country
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end

  def seed_data() do
    @seed_data
  end

  def get_country(id) do
    Repo.get_by(Country, id: id)
  end
end
