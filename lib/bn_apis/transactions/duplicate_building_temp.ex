defmodule BnApis.Transactions.DuplicateBuildingTemp do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Transactions.DuplicateBuildingTemp

  schema "duplicate_buildings_temp" do
    field :count, :integer
    field :hide, :boolean, default: false
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(duplicate_building_temp, attrs) do
    duplicate_building_temp
    |> cast(attrs, [:name, :count, :hide])
    |> validate_required([:name, :count])
  end

  def changeset(params) do
    %__MODULE__{}
    |> changeset(params)
  end

  def hide_buildings(building_name) do
    DuplicateBuildingTemp
    |> where([b], fragment("? % ?", b.name, ^building_name))
    |> Ecto.Query.update(set: [hide: true])
    |> Repo.update_all([])
  end
end
