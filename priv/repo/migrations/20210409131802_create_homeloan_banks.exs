defmodule BnApis.Repo.Migrations.CreateHomeloanBanks do
  use Ecto.Migration

  def change do
    create table(:homeloan_banks) do
      add(:name, :string, null: false)
      add(:order, :integer, null: false)
      timestamps()
    end

    create(unique_index(:homeloan_banks, ["lower(name)"], name: :uniq_homeloan_banks_name_idx))
  end
end
