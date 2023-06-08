defmodule BnApis.Repo.Migrations.ConstraintChangeInEmployeesCredentials do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:employees_credentials, [:phone_number])
    create unique_index(:employees_credentials, [:phone_number], where: "active = true")
  end
end
