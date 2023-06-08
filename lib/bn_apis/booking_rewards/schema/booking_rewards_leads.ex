defmodule BnApis.BookingRewards.Schema.BookingRewardsLead do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Organizations.{Broker, BillingCompany}
  alias BnApis.Organizations.Organization
  alias BnApis.Stories.{Story, LegalEntity}
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.BookingRewards.Schema.{BookingClient, BookingPayment, BookingRewardsLead}
  alias BnApis.BookingRewards.Status
  alias BnApis.Helpers.AuditedRepo
  alias BnApis.BookingRewards.Status
  alias BnApis.Stories.Schema.PocApprovals

  schema "booking_rewards_leads" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:booking_date, :integer)
    field(:booking_form_number, :string)
    field(:rera_number, :string)
    field(:unit_number, :string)
    field(:rera_carpet_area, :integer)
    field(:building_name, :string)
    field(:wing, :string)
    field(:agreement_value, :integer)
    field(:agreement_proof, :string)
    field(:invoice_number, :string)
    field(:invoice_date, :integer)
    field(:status_id, :integer)
    field(:status_message, :string)
    field(:approved_at, :naive_datetime)
    field(:booking_rewards_pdf, :string)
    field(:developer_response_pdf, :string)
    field(:deleted, :boolean, default: false)

    belongs_to(:story, Story)
    belongs_to(:broker, Broker)
    belongs_to(:booking_client, BookingClient, on_replace: :update)
    belongs_to(:booking_payment, BookingPayment, on_replace: :update)
    belongs_to(:billing_company, BillingCompany)
    belongs_to(:legal_entity, LegalEntity)

    belongs_to(:old_broker, Broker)
    belongs_to(:old_organization, Organization)

    has_many(:poc_approvals, PocApprovals)

    has_many(:invoices, Invoice)

    timestamps()
  end

  @required_fields [
    :booking_date,
    :unit_number,
    :rera_carpet_area,
    :building_name,
    :wing,
    :agreement_value,
    :story_id,
    :broker_id,
    :legal_entity_id,
    :status_id,
    :old_broker_id,
    :old_organization_id
  ]

  @optional_fields [
    :rera_number,
    :booking_form_number,
    :agreement_proof,
    :invoice_number,
    :invoice_date,
    :booking_client_id,
    :booking_payment_id,
    :billing_company_id,
    :status_message,
    :developer_response_pdf,
    :approved_at,
    :deleted,
    :booking_rewards_pdf
  ]

  def changeset(booking_rewards_lead, attrs) do
    old_status_id = Map.get(booking_rewards_lead, :status_id)

    booking_rewards_lead
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status_id, Status.ids())
    |> validate_status_change(old_status_id)
    |> maybe_cast_associated_items()
    |> validate_booking_amount()
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:booking_client_id)
    |> foreign_key_constraint(:booking_payment_id)
    |> foreign_key_constraint(:billing_company_id)
    |> foreign_key_constraint(:legal_entity_id)
    |> unique_constraint(:unique_booking_rewards_leads,
      name: :booking_rewards_lead_unique_index,
      message: "A Booking Reward with same Project, Booking Form Number, Unit Number and Wing exists."
    )
  end

  defp maybe_cast_associated_items(changeset) do
    changeset =
      if not is_nil(changeset.params["booking_payment"]) do
        cast_assoc(changeset, :booking_payment, with: &BookingPayment.changeset(&1, &2))
      else
        changeset
      end

    if not is_nil(changeset.params["booking_client"]) do
      cast_assoc(changeset, :booking_client, with: &BookingClient.changeset(&1, &2))
    else
      changeset
    end
  end

  def create(params, user_map) do
    %BookingRewardsLead{}
    |> changeset(params)
    |> AuditedRepo.insert(user_map)
  end

  def get_by_uuid(uuid, preload \\ []) do
    BookingRewardsLead
    |> Repo.get_by(uuid: uuid, deleted: false)
    |> case do
      nil -> nil
      lead -> Repo.preload(lead, [:booking_client, :booking_payment] ++ preload)
    end
  end

  def update(booking_rewards_lead, params, user_map) do
    booking_rewards_lead
    |> changeset(params)
    |> AuditedRepo.update(user_map)
  end

  def booking_rewards_lead_changeset_serializer(brl_changeset) do
    booking_client_changes =
      if Map.has_key?(brl_changeset.changes, :booking_client) and not is_nil(brl_changeset.changes.booking_client) do
        brl_changeset.changes.booking_client.changes
      else
        nil
      end

    booking_payment_changes =
      if Map.has_key?(brl_changeset.changes, :booking_payment) and not is_nil(brl_changeset.changes.booking_payment) do
        brl_changeset.changes.booking_payment.changes
      else
        nil
      end

    brl_changeset.changes
    |> Map.put(:booking_client, booking_client_changes)
    |> Map.put(:booking_payment, booking_payment_changes)
  end

  defp validate_status_change(changeset, old_status_id) do
    old_state = if old_status_id == nil, do: nil, else: Status.get_status_from_id(old_status_id)
    new_state = get_field(changeset, :status_id) |> Status.get_status_from_id()

    if valid_status_change(old_state, new_state),
      do: changeset,
      else: add_error(changeset, :status_id, "Cannot change status from #{old_state} to #{new_state}")
  end

  defp valid_status_change(state, state) when not is_nil(state), do: true

  defp valid_status_change(old_state, new_state),
    do: Status.valid_status_change(old_state) |> Enum.any?(&(&1 == new_state))

  defp validate_booking_amount(changeset) do
    booking_payment = get_field(changeset, :booking_payment)
    agreement_value = get_field(changeset, :agreement_value)
    status_id = get_field(changeset, :status_id) |> Status.get_status_from_id()
    reject_status = status_id in ["rejected_by_bn", "rejected_by_finance", "rejected_by_crm"]

    if agreement_value >= booking_payment.token_amount do
      changeset
    else
      if reject_status and agreement_value < booking_payment.token_amount,
        do: changeset,
        else: add_error(changeset, :agreement_value, "Token amount cannot be greater than agreement amount")
    end
  end
end
