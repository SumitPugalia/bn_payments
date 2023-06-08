defmodule BnApis.Repo.Migrations.CreateLegalEntityPocTable do
  use Ecto.Migration

  def change do
    create table(:legal_entity_pocs) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:poc_name, :string, null: false)
      add(:phone_number, :string, null: false)
      add(:poc_type, :string, null: false)
      add(:email, :string)

      timestamps()
    end

    create(
      unique_index(
        :legal_entity_pocs,
        [:phone_number, :poc_type],
        name: :unique_legal_entity_pocs
      )
    )

    create(
      index(
        :legal_entity_pocs,
        ["lower(poc_name) varchar_pattern_ops"]
      )
    )
  end
end
