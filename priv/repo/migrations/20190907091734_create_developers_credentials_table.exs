defmodule BnApis.Repo.Migrations.CreateDevelopersCredentialsTable do
  use Ecto.Migration

  def change do
    create table(:developers_credentials) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :profile_image_url, :string
      add :phone_number, :string
      add :active, :boolean, default: false, null: false
      add :last_active_at, :naive_datetime
      timestamps()
    end

    create unique_index(:developers_credentials, [:phone_number])
  end
end
