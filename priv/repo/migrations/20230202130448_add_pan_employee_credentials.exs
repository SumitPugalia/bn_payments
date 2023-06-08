defmodule BnApis.Repo.Migrations.AddPanEmployeeCredentials do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add :pan, :string
    end
  end
end
