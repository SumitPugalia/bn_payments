defmodule BnApis.Repo.Migrations.AddAutoCreatedInCredentials do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :auto_created, :boolean, default: false
    end
  end
end
