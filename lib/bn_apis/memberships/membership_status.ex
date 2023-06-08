defmodule BnApis.Memberships.MembershipStatus do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Memberships.Membership
  alias BnApis.Memberships.MembershipStatus

  schema "membership_status" do
    field(:status, :string)
    field(:paytm_data, :map)
    field(:created_at, :integer)
    field(:bn_customer_id, :string)
    field(:short_url, :string)
    field(:payment_method, :string)
    field(:current_start, :integer)
    field(:current_end, :integer)

    belongs_to(:membership, Membership)

    timestamps()
  end

  @required [:status, :membership_id]
  @optional [
    :paytm_data,
    :created_at,
    :bn_customer_id,
    :short_url,
    :payment_method,
    :current_start,
    :current_end
  ]

  @doc false
  def changeset(membership_status, attrs) do
    membership_status
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:membership_id)
  end

  def create_membership_status!(
        membership,
        params
      ) do
    changeset =
      MembershipStatus.changeset(%MembershipStatus{}, %{
        membership_id: membership.id,
        status: params[:status],
        paytm_data: params[:paytm_data],
        created_at: params[:created_at],
        bn_customer_id: params[:bn_customer_id],
        short_url: params[:short_url],
        payment_method: params[:payment_method],
        current_start: params[:current_start],
        current_end: params[:current_end]
      })

    Repo.insert!(changeset)
  end
end
