defmodule BnApis.Repo.Migrations.AddCityToEmployeesCredentials do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add :city_id, references(:cities, on_delete: :nothing)
    end
  end
end
