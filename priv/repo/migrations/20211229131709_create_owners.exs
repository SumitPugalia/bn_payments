defmodule BnApis.Repo.Migrations.CreateOwners do
  use Ecto.Migration

  def change do
    create table(:owners) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :phone_number, :string

      timestamps()
    end

    create unique_index(:owners, [:phone_number])
  end
end
