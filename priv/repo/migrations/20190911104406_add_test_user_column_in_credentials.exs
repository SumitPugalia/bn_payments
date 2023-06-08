defmodule BnApis.Repo.Migrations.AddTestUserColumnInCredentials do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :test_user, :boolean, default: false
    end
  end
end
