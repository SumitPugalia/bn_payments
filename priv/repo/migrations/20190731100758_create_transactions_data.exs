defmodule BnApis.Repo.Migrations.CreateTransactionsData do
  use Ecto.Migration

  def change do
    create table(:transactions_data) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :registration_date, :naive_datetime
      add :amount, :integer
      add :doc_html, :string
      add :doc_number, :integer
      add :sro_id, :string
      add :doc_type_id, references(:transactions_doctypes, on_delete: :nothing)
      add :district_id, references(:transactions_districts, on_delete: :nothing)
      add :building_id, references(:buildings, on_delete: :nothing)

      timestamps()
    end

    create index(:transactions_data, [:doc_type_id])
    create index(:transactions_data, [:district_id])
    create index(:transactions_data, [:building_id])
  end
end
