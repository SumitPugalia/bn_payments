defmodule BnApis.Repo.Migrations.AddLegalEntityToStoryTransactions do
  use Ecto.Migration

  def change do
    alter table(:story_transactions) do
      add(:legal_entity_id, references(:legal_entities))
    end
  end
end
