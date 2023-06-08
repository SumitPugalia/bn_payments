defmodule BnApis.Repo.Migrations.CreateEventsTable do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :user_id, references(:credentials, on_delete: :nothing)
      add :type, :string
      add :action, :string
      add :data, :jsonb

      timestamps()
    end
  end
end
