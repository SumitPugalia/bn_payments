defmodule BnApis.Repo.Migrations.ChangeIndexInTransaction do
  use Ecto.Migration

  def change do
    alter table(:transactions_data) do
      add :year, :integer
    end

    drop_if_exists index(:transactions_data, [:sro_id, :doc_number],
                     name: :sro_doc_unique_constraint
                   )

    create unique_index(:transactions_data, [:sro_id, :doc_number, :year],
             name: :sro_doc_year_unique_constraint
           )
  end
end
