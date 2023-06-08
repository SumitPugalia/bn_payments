defmodule BnApis.Repo.Migrations.AddUniqueIndexInTransactionsData do
  use Ecto.Migration

  def change do
    create unique_index(:transactions_data, [:sro_id, :doc_number],
             name: :sro_doc_unique_constraint
           )
  end
end
