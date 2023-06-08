defmodule BnApis.Repo.Migrations.CreateRemoteConfig do
  use Ecto.Migration

  def change do
    create table(:remote_config) do
      add :ios_minimum_supported_version, :string
      add :android_minimum_supported_version, :string

      timestamps()
    end
  end
end
