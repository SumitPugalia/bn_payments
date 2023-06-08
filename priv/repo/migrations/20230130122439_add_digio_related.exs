defmodule BnApis.Repo.Migrations.AddDigioRelated do
  use Ecto.Migration

  def change do
    create table(:digio_docs, primary_key: false) do
      add :id, :string, primary_key: true, null: false
      add :is_active, :boolean, default: true
      add :is_agreement, :boolean
      add :agreement_type, :string
      add :agreement_status, :string
      add :file_name, :string
      add :created_at, :string
      add :self_signed, :boolean
      add :self_sign_type, :string
      add :no_of_pages, :integer
      add :signing_parties, {:array, :map}, default: []
      add :esign_link_map, {:array, :map}, default: []
      add :sign_request_details, :map
      add :channel, :string
      add :other_doc_details, :map
      add :attached_estamp_details, :map
      add :entity_type, :string
      add :entity_id, :integer
    end

    alter table(:assisted_property_post_agreements) do
      add :owner_agreement_status, :string, default: "not_created"
    end
  end
end
