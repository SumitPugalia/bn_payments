defmodule BnApis.Repo.Migrations.CreateSalesPersons do
  use Ecto.Migration

  def change do
    create table(:sales_persons) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :phone_number, :string
      add :designation, :string
      add :project_id, references(:projects, on_delete: :nothing)

      timestamps()
    end

    create index(:sales_persons, [:project_id])
  end
end
