defmodule BnApis.Repo.Migrations.ChangeFieldTypeOfTransaction do
  use Ecto.Migration

  def change do
    alter table(:transactions_buildings) do
      modify :place_id, :text
    end
  end
end
