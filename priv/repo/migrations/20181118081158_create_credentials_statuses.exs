defmodule BnApis.Repo.Migrations.CreateCredentialsStatuses do
  use Ecto.Migration

  def change do
    create table(:credentials_statuses, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:credentials_statuses, [:name])
  end
end
