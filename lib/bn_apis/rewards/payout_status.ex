defmodule BnApis.Rewards.PayoutStatus do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Repo
  alias BnApis.Rewards.PayoutStatus
  alias BnApis.Rewards.Payout

  schema "payout_status" do
    field(:status, :string)
    field(:razorpay_data, :map)
    belongs_to(:rewards_payout, Payout)
    timestamps()
  end

  @required [:status, :rewards_payout_id]
  @optional [:razorpay_data]

  @doc false
  def changeset(payout_status, attrs) do
    payout_status
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:rewards_payout_id)
  end

  def create_payout_status!(
        payout,
        status,
        razorpay_data
      ) do
    changeset =
      PayoutStatus.changeset(%PayoutStatus{}, %{
        rewards_payout_id: payout.id,
        status: status,
        razorpay_data: razorpay_data
      })

    payout_status = Repo.insert!(changeset)
    payout_status
  end
end
