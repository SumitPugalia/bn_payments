defmodule BnApis.Repo.Migrations.AddPanelAutoCreatedInCredentials do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :panel_auto_created, :boolean, default: false
    end
  end
end
