defmodule BnApis.Repo.Migrations.AddCommissionOnFieldInBanks do
  use Ecto.Migration

  def change do
    alter table(:homeloan_banks) do
      add :commission_on, :string
    end
  end
end
