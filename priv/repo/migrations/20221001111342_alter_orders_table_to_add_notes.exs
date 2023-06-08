defmodule BnApis.Repo.Migrations.AlterOrdersTableToAddNotes do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:notes, :string, null: true)
    end
  end
end
