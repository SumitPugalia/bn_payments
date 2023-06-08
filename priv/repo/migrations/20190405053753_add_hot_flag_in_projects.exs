defmodule BnApis.Repo.Migrations.AddHotFlagInProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :hot, :boolean, null: false, default: true
    end
  end
end
