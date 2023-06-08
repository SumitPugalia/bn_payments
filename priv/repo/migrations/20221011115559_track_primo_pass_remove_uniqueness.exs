defmodule BnApis.Repo.Migrations.TrackPrimoPassRemoveUniqueness do
  use Ecto.Migration

  def change do
    drop unique_index(:track_primo_pass, [:pass_identifier, :broker_id],
           name: :unique_pass_for_broker_index
         )

    alter table(:track_primo_pass) do
      remove :pass_identifier
      add :phone_number, :string, null: false
      add :email, :string, null: false
    end

    create unique_index(:track_primo_pass, [:phone_number])
    create unique_index(:track_primo_pass, [:email])
  end
end
