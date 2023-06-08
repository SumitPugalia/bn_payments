defmodule BnApis.Repo.Migrations.AddMeetingsTable do
  use Ecto.Migration

  def change do
    create table(:meetings) do
      add :latitude, :float
      add :longitude, :float
      add :notes, :string
      add :address, :string
      add :active, :boolean, default: false

      add :employee_credentials_id, references(:employees_credentials)
      add :broker_id, references(:brokers)
      timestamps()
    end
  end
end
