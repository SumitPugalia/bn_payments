defmodule BnApis.Contacts.BrokerUniverse do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Helpers.FormHelper

  schema "brokers_universe" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :locality, :string
    field :name, :string
    field :organization_name, :string
    field :phone_number, :string
    field :country_code, :string, default: "+91"

    timestamps()
  end

  @doc false
  def changeset(broker_universe, attrs) do
    broker_universe
    |> cast(attrs, [:name, :phone_number, :country_code, :organization_name, :locality])
    |> validate_required([:name, :phone_number, :country_code, :organization_name])
    |> FormHelper.validate_phone_number(:phone_number)
  end
end
