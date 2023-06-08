defmodule BnApis.Repo.Migrations.AddReasonsToTransaction do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :correct, :boolean
      add :wrong_reason, :text
    end
  end
end
