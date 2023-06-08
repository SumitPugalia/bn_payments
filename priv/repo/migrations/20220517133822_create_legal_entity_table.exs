defmodule BnApis.Repo.Migrations.CreateLegalEntityTable do
  use Ecto.Migration

  def change do
    create table(:legal_entities) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add(:legal_entity_name, :string, null: false)
      add(:billing_address, :string)
      add(:gst, :string)
      add(:pan, :string)
      add(:sac, :integer)
      add(:state_code, :integer)
      add(:place_of_supply, :string)
      add(:story_id, references(:stories))
      timestamps()
    end

    create index(:legal_entities, [:legal_entity_name])
    create index(:legal_entities, [:state_code])
    create index(:legal_entities, [:pan])
    create index(:legal_entities, [:gst])
  end
end
