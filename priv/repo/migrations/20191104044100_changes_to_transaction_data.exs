defmodule BnApis.Repo.Migrations.ChangesToTransactionData do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      remove :flat_no
      add :flat_no, :string
    end
  end
end
