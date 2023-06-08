defmodule BnApis.Stories.LegalEntityPocMapping do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Stories.LegalEntity
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.Stories.LegalEntityPocMapping

  schema "legal_entity_poc_mappings" do
    belongs_to(:legal_entity, LegalEntity)
    belongs_to(:legal_entity_poc, LegalEntityPoc)
    field(:assigned_by, :integer)

    field(:active, :boolean, default: true)

    timestamps()
  end

  @required_fields [:legal_entity_id, :legal_entity_poc_id, :assigned_by, :active]
  @fields @required_fields ++ []

  @doc false
  def changeset(legal_entity_poc_mapping, attrs) do
    legal_entity_poc_mapping
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:legal_entity_id)
    |> foreign_key_constraint(:legal_entity_poc_id)
    |> unique_constraint(:legal_entity_poc_id,
      name: :unique_legal_entity_poc_mapping_index,
      message: "The Legal Entity to POC mapping already exixts."
    )
  end

  def activate_legal_entity_poc_mapping(legal_entity_id, legal_entity_poc_id, logged_in_user) do
    case fetch(legal_entity_id, legal_entity_poc_id) do
      nil ->
        attrs = %{
          legal_entity_id: legal_entity_id,
          legal_entity_poc_id: legal_entity_poc_id,
          assigned_by: logged_in_user,
          active: true
        }

        create!(attrs)

      legal_entity_poc_mapping ->
        update!(legal_entity_poc_mapping, %{active: true, assigned_by: logged_in_user})
    end
  end

  def deactivate_legal_entity_poc_mapping(legal_entity_id, legal_entity_poc_id, logged_in_user) do
    case fetch(legal_entity_id, legal_entity_poc_id) do
      nil ->
        {:ok, nil}

      legal_entity_poc_mapping ->
        update!(legal_entity_poc_mapping, %{active: false, assigned_by: logged_in_user})
    end
  end

  def get_active_pocs_for_legal_entity(legal_entity_id) do
    LegalEntityPocMapping
    |> where([m], m.legal_entity_id == ^legal_entity_id and m.active == true)
    |> select([m], m.legal_entity_poc_id)
    |> Repo.all()
  end

  def get_legal_entity_pocs_for_legal_entity(legal_entity_id) do
    LegalEntityPocMapping
    |> where([m], m.legal_entity_id == ^legal_entity_id and m.active == true)
    |> preload([:legal_entity_poc])
    |> Repo.all()
    |> Enum.map(fn poc ->
      %{
        id: poc.legal_entity_poc.id,
        uuid: poc.legal_entity_poc.uuid,
        poc_name: poc.legal_entity_poc.poc_name,
        phone_number: poc.legal_entity_poc.phone_number,
        poc_type: poc.legal_entity_poc.poc_type,
        email: poc.legal_entity_poc.email
      }
    end)
  end

  # Private methods

  defp create!(attrs) do
    LegalEntityPocMapping.changeset(%LegalEntityPocMapping{}, attrs)
    |> Repo.insert!()
  end

  defp update!(legal_entity_poc_mapping, attrs) do
    LegalEntityPocMapping.changeset(legal_entity_poc_mapping, attrs)
    |> Repo.update!()
  end

  defp fetch(legal_entity_id, legal_entity_poc_id) do
    Repo.one(
      from(mapping in LegalEntityPocMapping,
        where:
          mapping.legal_entity_id == ^legal_entity_id and
            mapping.legal_entity_poc_id == ^legal_entity_poc_id
      )
      |> limit(1)
    )
  end
end
