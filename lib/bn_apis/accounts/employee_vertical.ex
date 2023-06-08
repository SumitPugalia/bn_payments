defmodule BnApis.Accounts.EmployeeVertical do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "employees_verticals" do
    field(:id, :integer, primary_key: true)
    field(:name, :string)
    field(:identifier, :string)
    field(:active, :boolean, default: true)

    timestamps()
  end

  @field [:id, :name, :identifier]
  @doc false
  def changeset(vertical, params) do
    vertical
    |> cast(params, @field)
    |> validate_required(@field)
    |> unique_constraint(:name)
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  @verticals [
    %{
      "id" => 1,
      "identifier" => "BN",
      "name" => "Bn",
      "active" => true
    },
    %{
      "id" => 2,
      "identifier" => "PROJECT",
      "name" => "Project",
      "active" => true
    },
    %{
      "id" => 3,
      "identifier" => "OWNER",
      "name" => "Owner",
      "active" => true
    },
    %{
      "id" => 4,
      "identifier" => "COMMERCIAL",
      "name" => "Commercial",
      "active" => true
    },
    %{
      "id" => 5,
      "identifier" => "HOMELOAN",
      "name" => "Home Loan",
      "active" => true
    },
    %{
      "id" => 6,
      "identifier" => "ASSISTED",
      "name" => "Assisted",
      "active" => true
    }
  ]

  def seed_data(), do: @verticals

  def default_vertical_id(), do: get_vertical_by_identifier("BN") |> Map.get("id")

  def get_vertical_by_id(vertical_id) do
    @verticals
    |> Enum.filter(&(&1["id"] == vertical_id and &1["active"] == true))
    |> List.first()
  end

  def get_vertical_by_identifier(vertical_identifier) do
    @verticals
    |> Enum.filter(&(&1["identifier"] == vertical_identifier and &1["active"] == true))
    |> List.first()
  end

  def get_all_verticals() do
    @verticals
  end
end
