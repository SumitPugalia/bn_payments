defmodule BnApis.DigioDocs.Schema.DigioDoc do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "digio_docs" do
    field :id, :string, primary_key: true
    field :is_active, :boolean, default: true
    field :is_agreement, :boolean
    field :agreement_type, :string
    field :agreement_status, :string
    field :file_name, :string
    field :created_at, :string
    field :self_signed, :boolean
    field :self_sign_type, :string
    field :no_of_pages, :integer
    field :signing_parties, {:array, :map}, default: []
    field :esign_link_map, {:array, :map}, default: []
    field :sign_request_details, :map
    field :channel, :string
    field :other_doc_details, :map
    field :attached_estamp_details, :map
    field :entity_type, :string
    field :entity_id, :integer
  end

  @fields [
    :id,
    :is_agreement,
    :agreement_type,
    :agreement_status,
    :file_name,
    :created_at,
    :self_signed,
    :self_sign_type,
    :no_of_pages,
    :signing_parties,
    :esign_link_map,
    :sign_request_details,
    :channel,
    :other_doc_details,
    :attached_estamp_details,
    :entity_type,
    :entity_id
  ]
  @doc false
  def changeset(digioDoc, attrs) do
    digioDoc
    |> cast(attrs, @fields)
    |> validate_required([:id])
  end
end
