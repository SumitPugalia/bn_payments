defmodule BnApis.Repo.Migrations.CreateEmployeesCredentials do
  use Ecto.Migration

  def change do
    create table(:employees_credentials) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :profile_image_url, :string
      add :phone_number, :string
      add :active, :boolean, default: false, null: false
      add :last_active_at, :naive_datetime
      add :employee_role_id, references(:employees_roles, on_delete: :nothing)

      timestamps()
    end

    create index(:employees_credentials, [:employee_role_id])
    create unique_index(:employees_credentials, [:phone_number])
  end
end
