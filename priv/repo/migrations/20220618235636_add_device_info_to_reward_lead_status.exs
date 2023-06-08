defmodule BnApis.Repo.Migrations.AddDeviceInfoToRewardLeadStatus do
  use Ecto.Migration

  def change do
    alter table(:rewards_lead_statuses) do
      add :app_version, :string
      add :device_manufacturer, :string
      add :device_model, :string
      add :device_os_version, :string
    end
  end
end
