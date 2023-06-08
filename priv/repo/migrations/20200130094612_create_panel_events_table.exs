defmodule BnApis.Repo.Migrations.CreatePanelEventsTable do
  use Ecto.Migration

  def change do
    create table(:panel_events) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :employees_credentials_id, references(:employees_credentials, on_delete: :nothing)
      add :type, :string
      add :action, :string
      add :data, :jsonb

      timestamps()
    end
  end
end
