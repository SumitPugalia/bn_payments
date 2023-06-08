defmodule BnApis.Repo.Migrations.AddAppVersion do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :app_version, :string
    end

    create index(:credentials, [:app_version])
  end
end
