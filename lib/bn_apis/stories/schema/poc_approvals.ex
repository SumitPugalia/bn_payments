defmodule BnApis.Stories.Schema.PocApprovals do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.BookingRewards.Schema.BookingRewardsLead

  @fields ~w(legal_entity_poc_id invoice_id booking_rewards_lead_id approved_at action role_type)a
  @required_fields ~w(legal_entity_poc_id approved_at action role_type)a

  schema "poc_invoice_approvals" do
    belongs_to :legal_entity_poc, LegalEntityPoc
    belongs_to :invoice, Invoice
    belongs_to :booking_rewards_lead, BookingRewardsLead
    field :approved_at, :integer
    field :action, Ecto.Enum, values: ~w(approved rejected change)a
    field :role_type, :string
    field :ip, :string

    timestamps()
  end

  def new(params), do: changeset(%__MODULE__{}, params)

  defp changeset(struct, attrs) do
    struct
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> valid_reference()
  end

  defp valid_reference(changeset) do
    invoice_id = get_field(changeset, :invoice_id)
    booking_rewards_lead_id = get_field(changeset, :booking_rewards_lead_id)

    cond do
      is_nil(invoice_id) and is_nil(booking_rewards_lead_id) ->
        add_error(changeset, :invoice_id, "need a valid invoice or booking reward lead")

      not is_nil(invoice_id) and is_nil(booking_rewards_lead_id) ->
        foreign_key_constraint(changeset, :invoice_id)

      is_nil(invoice_id) and not is_nil(booking_rewards_lead_id) ->
        foreign_key_constraint(changeset, :booking_rewards_lead_id)
    end
  end
end
