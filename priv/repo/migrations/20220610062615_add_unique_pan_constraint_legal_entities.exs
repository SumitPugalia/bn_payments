defmodule BnApis.Repo.Migrations.AddUniquePanConstraintLegalEntities do
  use Ecto.Migration

  def change do
    create(
      unique_index(
        :legal_entities,
        ["lower(pan)"],
        name: :unique_pan_legal_entities_index
      )
    )
  end
end
