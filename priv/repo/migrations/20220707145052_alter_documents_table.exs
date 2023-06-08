defmodule BnApis.Repo.Migrations.AlterDocumentsTable do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      remove :entity_id
      remove :uploader_id
      add(:entity_id, :integer)
      add(:uploader_id, :integer)
    end
  end
end
