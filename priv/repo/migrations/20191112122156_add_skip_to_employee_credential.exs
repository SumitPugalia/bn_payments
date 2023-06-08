defmodule BnApis.Repo.Migrations.AddSkipToEmployeeCredential do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add :skip_allowed, :boolean, default: false, null: false
    end
  end
end
