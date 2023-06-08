defmodule BnApis.Schemas.LegalEntityPoc do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Stories.LegalEntity
  alias BnApis.Helpers.FormHelper
  alias BnApis.Repo

  schema "legal_entity_pocs" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:poc_name, :string)
    field(:phone_number, :string)
    field(:country_code, :string, default: "+91")
    # String Enum -> ["Finance", "CRM"]
    field(:poc_type, :string)
    field(:email, :string)
    field :active, :boolean
    field :last_active_at, :naive_datetime

    many_to_many(:legal_entities, LegalEntity, join_through: "legal_entity_poc_mappings", on_replace: :delete)

    timestamps()
  end

  @fields [
    :uuid,
    :poc_name,
    :phone_number,
    :poc_type,
    :email
  ]

  @seeds [
    %{
      poc_name: "Auto Approve",
      phone_number: "9373200897",
      country_code: "+91",
      poc_type: "Finance",
      email: "jr@brokernetwork.app",
      active: true
    },
    %{
      poc_name: "Auto Approve",
      phone_number: "9373200897",
      country_code: "+91",
      poc_type: "CRM",
      email: "jr@brokernetwork.app",
      active: true
    }
  ]

  @admin "Admin"
  @finance "Finance"
  @crm "CRM"

  @poc_type [@admin, @finance, @crm]

  @required_fields [:poc_name, :phone_number, :poc_type]
  @doc false
  def changeset(legal_entity_poc, attrs \\ %{}) do
    legal_entity_poc
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_change(:poc_type, &validate_poc_type/2)
    |> validate_format(:email, ~r/@/, message: "Invalid Email format.")
    |> FormHelper.validate_phone_number(:phone_number)
    |> unique_constraint(:phone_number,
      name: :unique_legal_entity_pocs,
      message: "A legal entity POC with same phone number and type exists."
    )
  end

  def seed_data, do: @seeds

  def poc_types, do: @poc_type
  def poc_type_finance, do: @finance
  def poc_type_crm, do: @crm
  def poc_type_admin, do: @admin

  def auto_approve_bots() do
    __MODULE__
    |> where([l], l.phone_number == ^"9373200897")
    |> Repo.all()
  end

  def validate_poc_type(:poc_type, poc_type) do
    invalid_poc_type? = not Enum.member?(@poc_type, poc_type)

    case invalid_poc_type? do
      true ->
        [poc_type: "POC Type is not valid."]

      false ->
        []
    end
  end

  def update_last_active_at_query(id) do
    __MODULE__
    |> where(id: ^id)
    |> Ecto.Query.update(
      set: [
        last_active_at: fragment("date_trunc('second',now() AT TIME ZONE 'UTC')")
      ]
    )
  end

  def get_by_id(nil), do: nil
  def get_by_id(id), do: Repo.get_by(__MODULE__, id: id)

  def get_by_uuid(nil), do: nil
  def get_by_uuid(uuid), do: Repo.get_by(__MODULE__, uuid: uuid)

  def get_by_phone_number(phone_number, country_code), do: Repo.get_by(__MODULE__, country_code: country_code, phone_number: phone_number, active: true)
end
