defmodule BnApis.Posts.Schema.PostLead do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Accounts.EmployeeCredential

  @schema_name "post_leads"

  def schema_name(), do: @schema_name

  schema "post_leads" do
    field :post_type, :string
    field :post_uuid, :string
    field :source, :string
    field :country_code, :string
    field :phone_number, :string
    field :lead_status, :string
    field :slash_reference_id, :string
    field :pushed_to_slash, :boolean, default: false
    field :token_id, :string
    field :notes, :string
    belongs_to :created_by_employee_credential, EmployeeCredential
    timestamps()
  end

  @required [
    :post_type,
    :post_uuid,
    :source,
    :country_code,
    :phone_number,
    :created_by_employee_credential_id
  ]
  @optional [
    :slash_reference_id,
    :pushed_to_slash,
    :lead_status,
    :token_id,
    :notes
  ]

  @doc false
  def changeset(post_lead, attrs \\ %{}) do
    post_lead
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> assoc_constraint(:created_by_employee_credential)
  end
end
