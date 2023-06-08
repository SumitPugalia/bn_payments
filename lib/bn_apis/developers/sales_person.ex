defmodule BnApis.Developers.SalesPerson do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Developers.{Project, SalesPerson}
  alias BnApis.Helpers.FormHelper

  schema "sales_persons" do
    field(:designation, :string)
    field(:name, :string)
    field(:phone_number, :string)
    field(:uuid, Ecto.UUID, read_after_writes: true)
    belongs_to(:project, Project)

    timestamps()
  end

  @doc false
  def changeset(sales_person, attrs) do
    sales_person
    |> cast(attrs, [:uuid, :name, :phone_number, :designation, :project_id])
    |> validate_required([:name, :phone_number, :designation])
    |> FormHelper.validate_phone_number(:phone_number)
  end

  def create(attrs) do
    %SalesPerson{}
    |> SalesPerson.changeset(attrs)
    |> Repo.insert()
  end
end
