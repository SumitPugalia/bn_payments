defmodule BnApis.AssistedProperty.Schema.AssistedPropertyPostAgreementLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.AssistedProperty.Schema.AssistedPropertyPostAgreement
  alias BnApis.Accounts.EmployeeCredential

  schema "assisted_property_post_agreement_log" do
    field :status, Ecto.Enum, values: ~w(assigned in_progress in_review assisted deal_done commission_collected failed)a
    field :notes, :string

    belongs_to :agreement, AssistedPropertyPostAgreement
    belongs_to :updated_by, EmployeeCredential

    timestamps()
  end

  @required [:status, :updated_by_id, :agreement_id]
  @optional [:notes]
  def changeset(assisted_property_post_agreement_log, attrs) do
    assisted_property_post_agreement_log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> assoc_constraint(:agreement)
    |> assoc_constraint(:updated_by)
  end
end
