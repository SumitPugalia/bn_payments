defmodule BnApis.AssistedProperty.Schema.AssistedPropertyPostAgreement do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Buildings.Building
  alias BnApis.Posts.ResalePropertyPost

  @schema_name "assisted_property_post_agreements"

  @derive Jason.Encoder
  schema "assisted_property_post_agreements" do
    field :uuid, Ecto.UUID
    field :status, Ecto.Enum, values: ~w(assigned in_progress in_review assisted deal_done commission_collected failed expired)a
    field :notes, :string
    field :is_active, :boolean, default: true
    field :owner_agreement_status, Ecto.Enum, values: [:not_created, :pending, :signed], default: :not_created
    field :validity_in_days, :integer
    field :payment_date, :integer
    field :current_start, :integer
    field :current_end, :integer

    belongs_to(:resale_property_post, ResalePropertyPost,
      foreign_key: :resale_property_post_id,
      references: :id
    )

    belongs_to :building, Building
    belongs_to :assisted_by, EmployeeCredential
    belongs_to :assigned_by, EmployeeCredential
    belongs_to :updated_by, EmployeeCredential

    timestamps()
  end

  @required [:resale_property_post_id, :building_id, :status, :assisted_by_id, :assigned_by_id, :updated_by_id, :is_active, :owner_agreement_status]
  @optional [:notes, :validity_in_days, :payment_date, :current_start, :current_end]

  def schema_name(), do: @schema_name

  def changeset(assisted_property_post_agreement, attrs) do
    assisted_property_post_agreement
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> assoc_constraint(:resale_property_post)
    |> assoc_constraint(:assisted_by)
    |> assoc_constraint(:assigned_by)
    |> assoc_constraint(:updated_by)
  end
end
