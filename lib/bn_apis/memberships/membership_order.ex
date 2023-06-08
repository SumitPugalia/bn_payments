defmodule BnApis.Memberships.MembershipOrder do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Memberships.Membership
  alias BnApis.Memberships.MembershipOrder
  alias BnApis.Helpers.PaytmMembershipHelper

  schema "membership_orders" do
    field(:order_id, :string)
    field(:order_status, :string)
    field(:order_amount, :string)
    field(:order_creation_date, :integer)
    field(:response_message, :string)
    field(:resp_code, :string)
    field(:txn_id, :string)
    field(:invoice_url, :string)

    field(:gst, :string)
    field(:gst_legal_name, :string)
    field(:gst_pan, :string)
    field(:gst_constitution, :string)
    field(:gst_address, :string)
    field(:is_gst_invoice, :boolean)

    belongs_to(:membership, Membership)

    timestamps()
  end

  @required [:membership_id, :order_id, :order_status]
  @optional [
    :order_amount,
    :order_creation_date,
    :response_message,
    :resp_code,
    :txn_id,
    :invoice_url,
    :gst,
    :gst_legal_name,
    :gst_pan,
    :gst_constitution,
    :gst_address,
    :is_gst_invoice
  ]

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(membership_order, attrs) do
    membership_order
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:membership_id)
  end

  def status_changeset(order, attrs) do
    status_change_fields = [:order_status, :order_creation_date, :response_message, :resp_code, :txn_id]

    order
    |> cast(attrs, status_change_fields)
    |> validate_required([:order_status])
  end

  def get_membership_order(id) do
    Repo.get_by(MembershipOrder, id: id)
  end

  def create_membership_order!(
        membership,
        params
      ) do
    membership_order = Repo.get_by(MembershipOrder, order_id: params[:last_order_id])
    membership_order_params = get_params_for_membership_order(params[:last_order_id])

    if is_nil(membership_order) do
      changeset =
        MembershipOrder.changeset(%MembershipOrder{}, %{
          membership_id: membership.id,
          order_id: membership_order_params[:order_id],
          order_status: membership_order_params[:order_status],
          order_creation_date: membership_order_params[:order_creation_date],
          order_amount: membership_order_params[:order_amount],
          resp_code: membership_order_params[:resp_code],
          response_message: membership_order_params[:response_message]
        })

      membership_order = Repo.insert!(changeset)
      update_invoice(membership_order)
    else
      update_membership_order!(membership_order, membership_order_params)
    end
  end

  def update_gst!(%MembershipOrder{} = membership_order, params) do
    ch =
      MembershipOrder.changeset(membership_order, %{
        gst: params["gst"],
        gst_legal_name: params["gst_legal_name"],
        gst_pan: params["gst_pan"],
        gst_constitution: params["gst_constitution"],
        gst_address: params["gst_address"]
      })

    membership_order = Repo.update!(ch)
    update_invoice(membership_order, true)
    membership_order
  end

  def update_invoice(membership_order, notify_broker \\ false) do
    if not is_nil(membership_order) and membership_order.order_status == "SUCCESS" do
      Exq.enqueue(Exq, "invoices", BnApis.Memberships.MembershipOrderInvoiceWorker, [membership_order.id, notify_broker])
    end
  end

  def update_membership_order!(%MembershipOrder{} = membership_order, params) do
    ch = MembershipOrder.status_changeset(membership_order, params)
    membership_order = Repo.update!(ch)
    update_invoice(membership_order)
  end

  def get_orders_by_membership_id(membership_id) do
    MembershipOrder
    |> where([mo], mo.membership_id == ^membership_id)
    |> order_by(desc: :order_creation_date)
    |> select([mo], %{
      order_id: mo.order_id,
      order_status: mo.order_status,
      order_amount: mo.order_amount,
      order_creation_date: mo.order_creation_date,
      txn_id: mo.txn_id,
      resp_code: mo.resp_code,
      invoice_url: mo.invoice_url,
      response_message: mo.response_message
    })
    |> Repo.all()
  end

  def get_params_for_membership_order(order_id) do
    response = PaytmMembershipHelper.get_subscription_order_details(order_id)
    response = response["body"]

    order_status =
      cond do
        response["resultInfo"]["resultStatus"] == "TXN_SUCCESS" ->
          "SUCCESS"

        response["resultInfo"]["resultStatus"] == "PENDING" ->
          "PENDING"

        true ->
          "FAIL"
      end

    order_creation_date =
      response["txnDate"] |> NaiveDateTime.from_iso8601!() |> Timex.to_datetime("Asia/Kolkata") |> Timex.Timezone.convert("Etc/UTC") |> Timex.to_datetime() |> DateTime.to_unix()

    %{
      order_id: response["orderId"],
      order_status: order_status,
      order_creation_date: order_creation_date,
      order_amount: response["txnAmount"],
      txn_id: response["txnId"],
      response_message: response["resultInfo"]["resultMsg"],
      resp_code: response["resultInfo"]["resultCode"]
    }
  end
end
