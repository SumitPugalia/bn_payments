defmodule BnApis.Repo.Migrations.AddHomeloanDocuments do
  use Ecto.Migration

  def change do
    create table(:homeloan_documents) do
      add(:doc_url, :string, null: false)
      add(:doc_name, :string, null: false)
      add(:doc_type, :integer)
      add(:uploader_id, :integer)
      add(:uploader_type, :string)
      add(:access_to_cp, :boolean)
      add(:active, :boolean, default: true)

      add(:homeloan_lead_id, references(:homeloan_leads), null: false)

      timestamps()
    end
  end
end
