defmodule BnApis.Stories.Schema.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Stories.{LegalEntity}
  alias BnApis.Organizations.{Broker, BillingCompany, BrokerRole}
  alias BnApis.Stories.Schema.{InvoiceItem, BookingInvoice}
  alias BnApis.BookingRewards.Schema.BookingRewardsLead
  alias BnApis.Organizations.Organization
  alias BnApis.Stories.Schema.PocApprovals
  alias BnApis.Helpers.Utils
  alias BnApis.Accounts.Credential
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Homeloan.InvoiceRemarks

  schema "invoices" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    # String Enum: ["approved", "rejected", "paid", "draft", "changes_requested", "approval_pending", "admin_review_pending", "rejected_by_admin"]]
    field(:status, :string)
    field(:invoice_number, :string)
    field(:invoice_date, :integer)
    field(:invoice_pdf_url, :string)
    field(:is_created_by_piramal, :boolean, default: false)
    field(:proof_urls, {:array, :string})
    field(:change_notes, :string)
    field(:is_advance_payment, :boolean, default: false)
    field(:payment_utr, :string)
    # ["brokerage", "booking_reward"]
    field(:type, :string)
    field(:bonus_amount, :integer, default: 0)
    # String Enum: ["NEFT", "UTR"]
    field(:payment_mode, :string)
    field(:entity_id, :integer)
    field :remarks, :string
    field :rejection_reason, :string
    field :is_billed, :boolean
    field :billing_number, :string
    field :bn_commission, :float
    field :payment_received, :boolean
    field :is_tds_valid, :boolean
    field(:entity_type, Ecto.Enum, values: ~w(stories loan_disbursements)a)

    field :loan_disbursements, :any, virtual: true
    field :story, :any, virtual: true
    field(:gst_filling_status, :boolean, default: false)
    field(:total_payable_amount, :float)
    field(:tds_percentage, :float)
    field(:hold_gst, :boolean, default: false)

    has_many :invoice_approvals, PocApprovals

    belongs_to(:broker, Broker)
    belongs_to(:approved_by_super, EmployeeCredential)
    belongs_to(:legal_entity, LegalEntity)
    belongs_to(:billing_company, BillingCompany)
    belongs_to(:booking_rewards_lead, BookingRewardsLead)

    belongs_to(:old_broker, Broker)
    belongs_to(:old_organization, Organization)

    has_many(:invoice_items, InvoiceItem,
      foreign_key: :invoice_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:invoice_remarks, InvoiceRemarks,
      foreign_key: :invoice_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_one(:booking_invoice, BookingInvoice,
      foreign_key: :invoice_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    timestamps()
  end

  @fields [
    :uuid,
    :status,
    :invoice_number,
    :invoice_date,
    :invoice_pdf_url,
    :broker_id,
    :legal_entity_id,
    :billing_company_id,
    :is_created_by_piramal,
    :proof_urls,
    :change_notes,
    :is_advance_payment,
    :payment_utr,
    :bonus_amount,
    :type,
    :booking_rewards_lead_id,
    :payment_mode,
    :entity_id,
    :entity_type,
    :old_broker_id,
    :old_organization_id,
    :rejection_reason,
    :is_billed,
    :remarks,
    :billing_number,
    :bn_commission,
    :payment_received,
    :is_tds_valid,
    :approved_by_super_id,
    :gst_filling_status,
    :total_payable_amount,
    :tds_percentage,
    :hold_gst
  ]

  @required_fields [
    :status,
    :invoice_number,
    :invoice_date,
    :broker_id,
    :legal_entity_id,
    :billing_company_id,
    :type,
    :old_broker_id,
    :old_organization_id
  ]

  @valid_invoice_status [
    "invoice_requested",
    "approved_by_admin",
    "approved_by_super",
    "approved",
    "rejected",
    "paid",
    "draft",
    "changes_requested",
    "approval_pending",
    "deleted",
    "approved_by_finance",
    "approved_by_crm",
    "rejected_by_finance",
    "rejected_by_crm",
    "admin_review_pending",
    "rejected_by_admin"
  ]

  @valid_status_change %{
    nil => ["draft", "approval_pending", "approved_by_crm"],
    "admin_review_pending" => ["approval_pending", "rejected_by_admin"],
    "draft" => ["approval_pending", "deleted"],
    "approval_pending" => ["changes_requested", "approved", "rejected", "deleted"],
    "changes_requested" => ["approval_pending", "approved", "rejected", "deleted"],
    "approved" => ["approved_by_finance", "rejected", "rejected_by_finance", "changes_requested", "deleted"],
    "approved_by_finance" => ["approved_by_crm", "rejected", "rejected_by_crm", "changes_requested", "deleted"],
    "approved_by_crm" => ["paid"],
    "paid" => [],
    "rejected_by_finance" => [],
    "rejected_by_crm" => [],
    "rejected" => [],
    "deleted" => []
  }

  @valid_status_change_for_broker_assistant Map.merge(
                                              @valid_status_change,
                                              %{
                                                nil => ["draft", "admin_review_pending"],
                                                "draft" => ["admin_review_pending", "deleted"],
                                                "admin_review_pending" => ["approval_pending", "rejected_by_admin"]
                                              }
                                            )
  @valid_status_change_dsa %{
    nil => ["draft", "invoice_requested"],
    "draft" => ["invoice_requested", "deleted"],
    "invoice_requested" => ["changes_requested", "approved_by_admin", "rejected", "deleted"],
    "changes_requested" => ["approved_by_admin", "approved_by_super", "approved_by_finance", "rejected", "deleted"],
    "approved_by_admin" => ["changes_requested", "pending_from_super", "rejected", "deleted"],
    "pending_from_super" => ["changes_requested", "approved_by_super", "rejected", "deleted"],
    "approved_by_super" => ["changes_requested", "approved_by_finance", "rejected", "deleted"],
    "approved_by_finance" => ["changes_requested", "paid", "rejected", "deleted", "payment_in_progress", "payment_failed"],
    "payment_in_progress" => ["paid", "payment_failed"],
    "payment_failed" => ["paid", "payment_in_progress"],
    "rejected" => ["invoice_requested"],
    "deleted" => [],
    "paid" => []
  }

  @doc false
  def changeset(invoice, attrs \\ %{}) do
    old_type = Map.get(invoice, :type)
    type = if is_nil(old_type), do: Map.get(attrs, :type), else: old_type

    old_status = Map.get(invoice, :status)
    {broker_role_id, role_type_id} = get_broker_role_id(invoice, attrs)

    invoice
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> maybe_cast_invoice_items()
    |> validate_invoice_status(type)
    |> validate_invoice_type(old_type)
    |> validate_status_change(old_status, broker_role_id, role_type_id)
    |> validate_entity_fields()
    |> validate_change(:payment_mode, &validate_payment_mode/2)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:legal_entity_id)
    |> foreign_key_constraint(:billing_company_id)
    |> foreign_key_constraint(:booking_rewards_lead)
  end

  ## Private APIs
  defp maybe_cast_invoice_items(changeset) do
    if get_field(changeset, :type) != "dsa" and is_nil(changeset.params["invoice_items"]) == false do
      cast_assoc(changeset, :invoice_items, with: &InvoiceItem.changeset(&1, &2, true), required: false)
    else
      changeset
    end
  end

  defp validate_invoice_type(changeset, nil), do: validate_inclusion(changeset, :type, ["brokerage", "booking_reward", "dsa"])

  defp validate_invoice_type(changeset, old_value) do
    if get_field(changeset, :type) == old_value,
      do: changeset,
      else: add_error(changeset, :status, "type change not allowed")
  end

  defp validate_invoice_status(changeset = %{valid?: true}, "dsa"), do: changeset

  defp validate_invoice_status(changeset = %{valid?: true}, _) do
    contains_booking_id? = not is_nil(get_field(changeset, :booking_rewards_lead_id))
    valid_status? = get_field(changeset, :status) in get_valid_status(%{booking_id: contains_booking_id?})

    if valid_status? do
      changeset
    else
      add_error(changeset, :status, "status not allowed")
    end
  end

  defp validate_invoice_status(changeset, _), do: changeset

  defp get_valid_status(%{booking_id: true}), do: @valid_invoice_status -- ~w(changes_requested)
  defp get_valid_status(_params), do: @valid_invoice_status

  defp validate_payment_mode(:payment_mode, payment_mode) do
    payment_mode = String.trim(payment_mode) |> String.upcase()

    if not Enum.member?(["NEFT", "UTR", "IMPS"], payment_mode) do
      [status: "Invalid payment mode."]
    else
      []
    end
  end

  def type_dsa(), do: "dsa"
  def type_reward(), do: "booking_reward"
  def type_brokerage(), do: "brokerage"

  defp validate_status_change(changeset = %{valid?: true}, old_status, broker_role_id, 1) do
    new_status = get_field(changeset, :status)

    if valid_status_change(old_status, new_status, broker_role_id, 1),
      do: changeset,
      else: add_error(changeset, :status, "Cannot change status from #{old_status} to #{new_status}")
  end

  defp validate_status_change(changeset = %{valid?: true}, old_status, _, 2) do
    new_status = get_field(changeset, :status)

    if valid_status_change_dsa(old_status, new_status),
      do: changeset,
      else: add_error(changeset, :status, "Cannot change status from #{old_status} to #{new_status}")
  end

  defp validate_status_change(changeset, _old_status, _broker_role_id, _role_type_id), do: changeset

  defp valid_status_change(status, status, _broker_role_id, _role_type_id) when not is_nil(status), do: true
  defp valid_status_change(status, status, nil, _role_type_id), do: false

  defp valid_status_change(old_status, new_status, broker_role_id, 1) do
    if broker_role_id == BrokerRole.chhotus().id do
      @valid_status_change_for_broker_assistant[old_status] |> Enum.any?(&(&1 == new_status))
    else
      @valid_status_change[old_status] |> Enum.any?(&(&1 == new_status))
    end
  end

  defp valid_status_change_dsa(status, status) when not is_nil(status), do: true
  defp valid_status_change_dsa(old_status, new_status), do: @valid_status_change_dsa[old_status] |> Enum.any?(&(&1 == new_status))

  defp validate_entity_fields(changeset = %{valid?: true}) do
    is_created_by_piramal = get_field(changeset, :is_created_by_piramal) |> Utils.parse_boolean_param()
    if not is_created_by_piramal, do: validate_required(changeset, [:entity_id, :entity_type]), else: changeset
  end

  defp validate_entity_fields(changeset), do: changeset

  defp get_broker_role_id(invoice, attrs) do
    broker_id =
      cond do
        not is_nil(invoice.broker_id) -> invoice.broker_id
        not is_nil(Map.get(attrs, :broker_id)) -> attrs[:broker_id]
        true -> nil
      end

    if not is_nil(broker_id) do
      cred = Credential.get_credential_from_broker_id(broker_id, [:broker])
      {cred.broker_role_id, cred.broker.role_type_id}
    else
      {nil, nil}
    end
  end
end
