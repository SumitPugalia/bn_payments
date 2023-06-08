defmodule BnApis.BookingRewards.Schema.BookingPayment do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.BookingRewards.Schema.{BookingPayment}
  alias BnApis.Helpers.S3Helper
  alias BnApis.Helpers.AuditedRepo

  schema "booking_payment" do
    field(:token_amount, :integer)
    field(:payment_mode, :string)
    field(:payment_proof, :string)

    timestamps()
  end

  @required_fields [
    :token_amount
  ]

  @optional [
    :payment_mode,
    :payment_proof
  ]

  def changeset(booking_payment, attrs) do
    booking_payment
    |> cast(attrs, @required_fields ++ @optional)
    |> validate_required(@required_fields)
  end

  def create(params, user_map) do
    %BookingPayment{}
    |> changeset(params)
    |> AuditedRepo.insert(user_map)
  end

  def get_by_id(id) do
    Repo.get!(BookingPayment, id)
  end

  def update(booking_payment, params, user_map) do
    booking_payment
    |> changeset(params)
    |> AuditedRepo.update(user_map)
  end

  def update_or_insert(booking_payment, params, user_map) do
    if is_nil(booking_payment) do
      create(params, user_map)
    else
      update(booking_payment, params, user_map)
    end
  end

  def to_map(nil), do: nil

  def to_map(%__MODULE__{} = booking_payment) do
    %{
      token_amount: booking_payment.token_amount,
      payment_mode: booking_payment.payment_mode,
      payment_proof: S3Helper.get_imgix_url(booking_payment.payment_proof)
    }
  end
end
