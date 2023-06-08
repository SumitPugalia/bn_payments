defmodule BnApis.Repo.Migrations.AddInstalledFlagToCredential do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :installed, :boolean, default: true, null: false
    end
  end
end
