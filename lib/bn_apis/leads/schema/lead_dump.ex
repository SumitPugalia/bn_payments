defmodule BnApis.Leads.Schema.LeadDump do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lead_dump" do
    field :name, :string
    field :phone, :string
    field :email, :string
    field :metadata, :map, default: %{}

    timestamps()
  end

  @fields [:name, :phone, :email, :metadata]
  @doc false
  def changeset(lead_dump, attrs) do
    lead_dump
    |> cast(attrs, @fields)
  end
end
