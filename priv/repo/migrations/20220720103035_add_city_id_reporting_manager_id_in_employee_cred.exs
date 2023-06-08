defmodule BnApis.Repo.Migrations.AddCityIdReportingManagerIdInEmployeeCred do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add(:reporting_manager_id, references(:employees_credentials))
      add(:access_city_ids, {:array, :integer})
    end
  end
end
