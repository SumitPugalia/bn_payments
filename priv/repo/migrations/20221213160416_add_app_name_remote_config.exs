defmodule BnApis.Repo.Migrations.AddAppNameRemoteConfig do
  use Ecto.Migration

  def change do
    alter table(:remote_config) do
      add :app_name, :string, null: false
    end

    create unique_index(:remote_config, [:app_name])
  end
end
