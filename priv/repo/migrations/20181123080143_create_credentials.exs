defmodule BnApis.Repo.Migrations.CreateCredentials do
  use Ecto.Migration

  def change do
    create table(:credentials) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :email, :string
      add :phone_number, :string
      add :phone_number_verified, :boolean, default: false, null: false

      add :profile_type_id, references(:credentials_profile_types, on_delete: :nothing),
        null: false

      add :status_id, references(:credentials_statuses, on_delete: :nothing), null: false
      add :broker_id, references(:brokers, on_delete: :nothing)

      timestamps()
    end

    create index(:credentials, [:profile_type_id])
    create index(:credentials, [:status_id])
    create index(:credentials, [:broker_id])
    create unique_index(:credentials, [:email])
    create unique_index(:credentials, [:phone_number])
  end
end
