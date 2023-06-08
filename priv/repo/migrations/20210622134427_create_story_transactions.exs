defmodule BnApis.Repo.Migrations.CreateStoryTransactions do
  use Ecto.Migration

  def change do
    create table(:story_transactions) do
      add(:amount, :float, null: false)
      add(:story_id, references(:stories), null: false)

      add(:employee_credential_id, references(:employees_credentials), null: false)

      timestamps()
    end
  end
end
