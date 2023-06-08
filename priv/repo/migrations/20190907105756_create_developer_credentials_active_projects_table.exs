defmodule BnApis.Repo.Migrations.CreateDeveloperCredentialsActiveProjectsTable do
  use Ecto.Migration

  def change do
    create table(:developers_credentials_projects) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :developers_credentials_id, references(:developers_credentials, on_delete: :nothing)
      add :project_id, references(:projects, on_delete: :nothing)
      add :active, :boolean, default: true
      timestamps()
    end

    create unique_index(:developers_credentials_projects, [
             :developers_credentials_id,
             :project_id
           ])
  end
end
