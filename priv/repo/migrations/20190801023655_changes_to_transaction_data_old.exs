defmodule BnApis.Repo.Migrations.ChangesToTransactionDataOld do
  use Ecto.Migration

  def up do
    alter table(:transactions_data) do
      remove :amount
      remove :doc_html
      add :amount, :decimal
      add :doc_html, :text
      add :flat_number, :integer
      add :floor_number, :integer
      add :rblDocType, :integer
    end
  end

  def down do
    alter table(:transactions_data) do
      add :amount, :integer
      add :doc_html, :string
      # remove :amount
      # remove :doc_html
      # remove :flat_number
      # remove :floor_number
      # remove :rblDocType
    end
  end
end
