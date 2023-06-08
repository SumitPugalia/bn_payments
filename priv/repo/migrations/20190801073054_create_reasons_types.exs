defmodule BnApis.Repo.Migrations.CreateReasonsTypes do
  use Ecto.Migration

  def change do
    create table(:reasons_types, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:reasons_types, [:name])
  end
end
