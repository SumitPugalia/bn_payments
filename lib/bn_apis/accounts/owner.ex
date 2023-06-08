defmodule BnApis.Accounts.Owner do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.Owner
  alias BnApis.Accounts.Credential

  schema "owners" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:phone_number, :string)
    field(:name, :string)
    field(:is_broker, :boolean, default: false)
    field :email, :string
    field :country_code, :string

    timestamps()
  end

  @fields [:name, :phone_number, :email, :country_code, :is_broker]
  @required_fields [:name, :phone_number, :country_code]

  @doc false
  def changeset(owner, attrs \\ %{}) do
    owner
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:phone_uniqueness, name: :phone_uniqueness)
  end

  def all_owners() do
    Owner
    |> Repo.all()
  end

  def update(owner, attrs) do
    owner
    |> Owner.changeset(attrs)
    |> Repo.update()
  end

  def fetch_owner_from_phone(country_code, phone_number) do
    Owner |> Repo.get_by(country_code: country_code, phone_number: phone_number)
  end

  def update_broker_flag(id, is_broker) do
    Repo.get(Owner, id) |> Owner.update(%{"is_broker" => is_broker})
    {:ok, %{"success" => true}}
  end

  def get_owner_by_phone(phone_number, country_code \\ "+91") do
    if is_nil(phone_number) do
      {:ok, %{}}
    else
      owner =
        Owner
        |> where([o], o.country_code == ^country_code and o.phone_number == ^phone_number)
        |> select([o], %{
          name: o.name,
          is_broker_flag: o.is_broker,
          country_code: o.country_code,
          phone_number: o.phone_number,
          email: o.email,
          id: o.id,
          uuid: o.uuid
        })
        |> Repo.all()
        |> List.last()

      is_broker = Credential |> where([c], c.phone_number == ^phone_number) |> Repo.all() |> length > 0

      owner = if is_nil(owner), do: %{}, else: owner

      owner = Map.put(owner, "is_broker", is_broker)

      {:ok, owner}
    end
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Get in case record exists
  """
  def create_or_get_owner(params) do
    cc = if is_nil(params["owner_country_code"]), do: "+91", else: params["owner_country_code"]

    params = %{
      "name" => params["owner_name"],
      "email" => params["owner_email"],
      "phone_number" => params["owner_phone"],
      "country_code" => cc
    }

    case fetch_owner_from_phone(params["country_code"], params["phone_number"]) do
      nil ->
        %Owner{}
        |> Owner.changeset(params)
        |> Repo.insert()

      owner ->
        {:ok, owner}
    end
  end

  def create_owner(params) do
    cc = if is_nil(params["owner_country_code"]), do: "+91", else: params["owner_country_code"]

    params = %{
      "name" => params["owner_name"],
      "email" => params["owner_email"],
      "phone_number" => params["owner_phone"],
      "country_code" => cc
    }

    %Owner{}
    |> Owner.changeset(params)
    |> Repo.insert()
  end
end
