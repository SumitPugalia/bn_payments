defmodule BnApis.Rewards.InvoicePayout do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Helpers.{AuditedRepo, Utils, Time, ApplicationHelper, ExternalApiHelper}
  alias BnApis.{Repo, Log}
  alias BnApis.Organizations.Broker
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Rewards.InvoicePayout
  alias BnApis.Stories.Invoice, as: Invoices
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.BankAccount

  schema "invoice_payouts" do
    field :payout_id, :string
    field :status, :string
    field :account_number, :string
    field :utr, :string
    field :fund_account_id, :string
    field :amount, :float
    field :created_at, :integer
    field :purpose, :string
    field :mode, :string
    field :reference_id, :string
    field :currency, :string

    field :failure_reason, :string
    field :gateway_name, :string
    field :razorpay_data, :map

    belongs_to :invoice, Invoice
    belongs_to :broker, Broker

    timestamps()
  end

  @pending_status "pending"
  @rejected "rejected"
  @processing_status "processing"
  @processed_status "processed"
  @reversed_status "reversed"
  @cancelled "cancelled"
  @time_delay 3

  @required [
    :status,
    :fund_account_id,
    :amount,
    :invoice_id,
    :broker_id,
    :gateway_name
  ]
  @optional [
    :mode,
    :purpose,
    :payout_id,
    :account_number,
    :currency,
    :utr,
    :reference_id,
    :created_at,
    :failure_reason,
    :razorpay_data
  ]

  def new(params), do: changeset(%__MODULE__{}, params)
  @doc false
  def changeset(payout, attrs) do
    payout
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:invoice_id)
  end

  def get_invoice_payout(invoice_id) do
    case InvoicePayout |> Repo.get_by(invoice_id: invoice_id) do
      nil -> nil
      payout -> get_payout_params(payout)
    end
  end

  defp get_payout_params(payout) do
    %{
      payout_id: payout.payout_id,
      status: payout.status,
      account_number: payout.account_number,
      utr: payout.utr,
      amount: payout.amount,
      fund_account_id: payout.fund_account_id,
      created_at: payout.created_at,
      purpose: payout.purpose,
      mode: payout.mode,
      reference_id: payout.reference_id,
      currency: payout.currency,
      failure_reason: payout.failure_reason
    }
  end

def add_new_pending_payout(invoice, fund_id, user_map) do
    %{
      status: @pending_status,
      fund_account_id: fund_id,
      amount: invoice.total_payable_amount * 100,
      invoice_id: invoice.id,
      broker_id: invoice.broker.id,
      gateway_name: "razorpay",
      account_number: invoice.billing_company.bank_account.account_number
    }
    |> new()
    |> AuditedRepo.insert(user_map)
    |> case do
      {:ok, payout} ->
        Exq.enqueue_in(Exq, "invoice_payout", @time_delay, BnApis.Workers.Invoice.InvoiceRazorpayWorker, [payout.id])
      {:error, error} ->
        {:error, error}
     end
  end

  def update_response_body(invoice_payout, response) do
    user_map = %{user_id: 0, user_type: "system"}
    invoice_payout = invoice_payout |> Repo.preload([:invoice, :broker])
    changeset(invoice_payout, %{
      payout_id: response["id"],
      status: response["status"],
      amount: response["amount"],
      currency: response["currency"],
      account_number: response["account_number"],
      utr: response["utr"],
      mode: response["mode"],
      reference_id: response["reference_id"],
      created_at: response["created_at"],
      failure_reason: response["failure_reason"],
      purpose: response["purpose"],
      razorpay_data: response
    })
     |> AuditedRepo.update(user_map)
     |> case do
      {:ok, payout} ->
        cond do
          invoice_payout.status != @processed_status and response["status"] == @processed_status ->
            invoice_payout.invoice
            |> Invoice.changeset(%{payment_utr: response["utr"], payment_mode:  response["mode"], status: "paid"})
            |> AuditedRepo.update(user_map)
            |> case do
              {:ok, result_payout} ->
                send_whatsapp_on_successfull_transaction(invoice_payout, response["utr"], response["created_at"])
                {:ok, result_payout}
              {:error, err} -> {:error, err}
            end

          response["status"] in [@rejected, @reversed_status, @cancelled]->
            Invoices.change_status(invoice_payout.invoice.uuid, user_map, "payment_failed", nil)

          true ->
            {:ok, payout}
        end
      {:error, err} -> {:error, err}
    end

  end

  def handle_payout_webhook(razorpay_order_id) do
    channel = ApplicationHelper.get_slack_channel()
    invoice_payout = InvoicePayout |> Repo.get_by(payout_id: razorpay_order_id)
    invoice_id = if(not is_nil(invoice_payout), do: invoice_payout.invoice_id ,else: nil)

    auth_key = ApplicationHelper.get_razorpay_auth_key()
    {status, response} =  ExternalApiHelper.get_razorpay_payout_details(razorpay_order_id, auth_key)
    case status do
      200 ->
        case invoice_payout do
          nil -> {:error, "invoice not found"}
          invoice_payout -> update_response_body(invoice_payout, response)
        end
      _ ->
        ApplicationHelper.notify_on_slack(
          "Issue in getting invoice payout status for invoice_id: #{invoice_id}, razorpay_response:#{Jason.encode!(response)}",
          channel
        )
    end
  end

  def get_payment_logs(invoice_id, page_no) do
    payout = InvoicePayout |> Repo.get_by(invoice_id: invoice_id)
    logs = Log.get_logs(payout.id, "invoice_payouts", page_no)
    {:ok, logs}
  end

  def payout_method(payout) do
    amount = Utils.format_float(payout.amount)
    mode = if(amount <= 5_00_00_000, do: "IMPS", else: "NEFT")
    %{
      "currency" => "INR",
      "amount" => amount,
      "mode" => mode,
      "purpose" => "payout",
      "queue_if_low_balance" => true
    }
  end

  def send_whatsapp_on_successfull_transaction(invoice_payout, utr_number, transaction_date) do
    cred = Credential.get_credential_from_broker_id(invoice_payout.broker_id)
    bank_account  = BankAccount |> Repo.get_by(billing_company_id: invoice_payout.invoice.billing_company_id)
    values = get_payload_for_whatsapp(invoice_payout, bank_account, transaction_date, utr_number)

    Exq.enqueue(Exq, "send_sms", BnApis.Whatsapp.SendWhatsappMessageWorker, [
      cred.phone_number,
      "hl_auto_new",
      values,
      %{"entity_type" => "invoice_payouts", "entity_id" => invoice_payout.id}
    ])
  end

  def get_payload_for_whatsapp(invoice_payout, bank_account, transaction_date, utr_number) do
    transaction_date = Time.get_formatted_datetime(transaction_date, "%d-%m-%Y")
    [
      "#{Utils.format_float(invoice_payout.amount/100)}",
      bank_account.account_number,
      transaction_date,
      invoice_payout.invoice.invoice_number,
      utr_number
    ]
  end
end
