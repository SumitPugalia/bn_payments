defmodule BnApis.Repo.Migrations.CreateWhitelistedNumbers do
  use Ecto.Migration

  def change do
    create table(:whitelisted_numbers) do
      add :phone_number, :string

      timestamps()
    end

    create unique_index(:whitelisted_numbers, [:phone_number])
  end
end
