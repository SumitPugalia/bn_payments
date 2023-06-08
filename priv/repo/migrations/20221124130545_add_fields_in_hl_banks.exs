defmodule BnApis.Repo.Migrations.AddFieldsInHlBanks do
  use Ecto.Migration

  def change do
    alter table(:homeloan_banks) do
      modify(:order, :integer, null: true, from: :integer)
      add :is_editable, :boolean, default: false
      add :active, :boolean, default: false
      add :bn_code, :string
    end
  end
end
