defmodule BnApis.Repo.Migrations.AddPriorityDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add(:priority, :integer)
    end
  end
end
