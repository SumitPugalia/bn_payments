defmodule BnApis.Accounts.Schema.PayoutMapping do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Accounts.Schema.GatewayToCityMapping

  @fields ~w(contact_id fund_account_id active cilent_uuid payment_gateway_id)a

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "client_to_gateway_payout_mapping" do
    field(:contact_id, :string)
    field(:fund_account_id, :string)
    field(:active, :boolean)
    field(:cilent_uuid, Ecto.UUID)

    belongs_to(:payment_gateway, GatewayToCityMapping, type: Ecto.UUID)
    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
  end
end
