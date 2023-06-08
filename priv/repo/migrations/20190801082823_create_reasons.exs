defmodule BnApis.Repo.Migrations.CreateReasons do
  use Ecto.Migration

  def change do
    create table(:reasons, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false
      add :reason_type_id, references(:reasons_types, on_delete: :nothing)

      timestamps()
    end

    create index(:reasons, [:reason_type_id])
  end
end
