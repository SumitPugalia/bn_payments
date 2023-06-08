defmodule BnApis.Repo.Migrations.AddStutusIdHlDocuments do
  use Ecto.Migration

  def change do
    alter table(:homeloan_documents) do
      add(:lead_status_id, :integer)
    end
  end
end
