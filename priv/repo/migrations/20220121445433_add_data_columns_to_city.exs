defmodule BnApis.Repo.Migrations.AddDataColumnsToCity do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add(:helpline_numbers, :string)
    end
  end
end
