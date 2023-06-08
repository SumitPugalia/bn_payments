defmodule BnApis.Repo.Migrations.AddUniqueIndexInOwners do
  use Ecto.Migration

  def change do
    drop index(:owners, [:phone_number])
    create unique_index(:owners, [:phone_number, :country_code], name: :phone_uniqueness)
  end
end
