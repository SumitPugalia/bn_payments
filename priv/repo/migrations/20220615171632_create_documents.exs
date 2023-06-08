defmodule BnApis.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :doc_url, :string
      add :entity_type, :string
      add :entity_id, :string
      add :doc_name, :string
      add :uploader_id, :string
      add :uploader_type, :string
      add :is_active, :boolean
      add :type, :string

      timestamps()
    end
  end
end
