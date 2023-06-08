defmodule BnApis.Repo.Migrations.ChangeColumnsInFeedTransactionProjects do
  use Ecto.Migration

  def change do
    alter table(:feed_transaction_projects) do
      remove :story_id
      add(:feed_locality_id, :integer)
      add(:feed_locality_name, :string)
      add(:full_name, :string)
    end
  end
end
