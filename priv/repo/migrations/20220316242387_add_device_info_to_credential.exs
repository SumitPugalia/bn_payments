defmodule BnApis.Repo.Migrations.AddDeviceInfoToCredential do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :device_manufacturer, :string
      add :device_model, :string
      add :device_os_version, :string
    end
  end
end
