defmodule BnApis.Repo.Migrations.CreateCredentialsProfileTypes do
  use Ecto.Migration

  def change do
    create table(:credentials_profile_types, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:credentials_profile_types, [:name])
  end
end
