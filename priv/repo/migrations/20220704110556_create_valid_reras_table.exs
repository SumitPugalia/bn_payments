defmodule BnApis.Repo.Migrations.CreateValidRerasTable do
  use Ecto.Migration

  def change do
    create table(:valid_reras) do
      add(:rera_id, :string, null: false)
      add(:rera_name, :string, null: false)
      add(:rera_file, :string, null: false)

      timestamps()
    end

    create(
      index(
        :valid_reras,
        ["lower(rera_id)"]
      )
    )

    create(
      unique_index(
        :valid_reras,
        ["lower(rera_id)", "lower(rera_name)"],
        name: :unique_rera_index
      )
    )
  end
end
