defmodule BnApis.Repo.Migrations.TrackPrimoPass do
  use Ecto.Migration

  def change do
    create table(:track_primo_pass) do
      add :broker_id, :integer
      add :pass_identifier, :string
      add :payload, :map
      add :pass_data, :map
      add :status, :string

      timestamps()
    end

    create(
      unique_index(:track_primo_pass, [:pass_identifier, :broker_id],
        name: :unique_pass_for_broker_index
      )
    )
  end
end
