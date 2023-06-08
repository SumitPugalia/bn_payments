defmodule BnApis.Commercials.CommercialPropertyPocMapping do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Commercials.CommercialPropertyPost
  alias BnApis.Commercials.CommercialPropertyPoc
  alias BnApis.Commercials.CommercialPropertyPocMapping
  alias BnApis.Repo

  alias BnApis.Accounts.EmployeeCredential

  schema "commercial_property_poc_mappings" do
    field :is_active, :boolean, default: true

    belongs_to :assigned_by, EmployeeCredential
    belongs_to(:commercial_property_poc, CommercialPropertyPoc)
    belongs_to(:commercial_property_post, CommercialPropertyPost)

    timestamps()
  end

  @fields [:is_active, :commercial_property_poc_id, :commercial_property_post_id, :assigned_by_id]

  @doc false
  def changeset(commercial_property_poc_mapping, attrs) do
    commercial_property_poc_mapping
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> unique_constraint(:unique_cppm_req,
      name: :commercial_property_post_poc_mappings_uniq_index,
      message: "active commercial property post poc mapping exists"
    )
  end

  def create_commercial_property_poc_mapping(commercial_property_post_id, commercial_property_poc_id, assigned_by_id) do
    row =
      CommercialPropertyPocMapping
      |> where(
        [cppm],
        cppm.commercial_property_post_id == ^commercial_property_post_id and
          cppm.commercial_property_poc_id == ^commercial_property_poc_id
      )
      |> Repo.one()

    poc_mapping_params = %{
      "commercial_property_post_id" => commercial_property_post_id,
      "is_active" => true,
      "commercial_property_poc_id" => commercial_property_poc_id,
      "assigned_by_id" => assigned_by_id
    }

    case row do
      nil ->
        changeset(%CommercialPropertyPocMapping{}, poc_mapping_params) |> Repo.insert()

      row ->
        case row.is_active do
          false ->
            changeset(row, poc_mapping_params) |> Repo.update()

          true ->
            {:ok, row}
        end
    end
  end

  def create_and_update_poc_mapping(nil, _commercial_property_post_id, _assigned_by_id), do: nil

  def create_and_update_poc_mapping(poc_ids, commercial_property_post_id, assigned_by_id) do
    all_pocs =
      CommercialPropertyPocMapping
      |> where([cppm], cppm.commercial_property_post_id == ^commercial_property_post_id and cppm.is_active == ^true)
      |> Repo.all()

    # discard all pocs first
    all_pocs
    |> Enum.map(fn poc -> poc |> CommercialPropertyPocMapping.changeset(%{"is_active" => false}) |> Repo.update() end)

    poc_ids
    |> Enum.map(fn poc_id ->
      CommercialPropertyPocMapping.create_commercial_property_poc_mapping(
        commercial_property_post_id,
        poc_id,
        assigned_by_id
      )
    end)
  end

  def get_commercial_poc_details(post_id) do
    CommercialPropertyPocMapping
    |> join(:inner, [cp], m in CommercialPropertyPoc, on: m.id == cp.commercial_property_poc_id and cp.is_active == true)
    |> where([cp, m], cp.commercial_property_post_id == ^post_id and cp.is_active == true)
    |> select([cp, m], %{
      name: m.name,
      email: m.email,
      phone: m.phone,
      poc_id: m.id,
      country_code: m.country_code
    })
    |> Repo.all()
  end
end
