defmodule BnApis.Repo.Migrations.CreateFeedTransactionLocalities do
  use Ecto.Migration

  def change do
    create table(:feed_transaction_localities) do
      add(:feed_locality_id, :integer)
      add(:feed_locality_name, :string)

      add :locality_id, references(:localities, on_delete: :nothing)

      timestamps()
    end

    create(unique_index(:feed_transaction_localities, [:locality_id]))
    create(unique_index(:feed_transaction_localities, [:feed_locality_id]))
  end
end
