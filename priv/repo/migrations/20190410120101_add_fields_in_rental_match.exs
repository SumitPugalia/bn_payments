defmodule BnApis.Repo.Migrations.AddFieldsInRentalMatch do
  use Ecto.Migration

  def change do
    alter table(:rental_matches) do
      add :already_contacted, :boolean, default: false
      add :already_contacted_by, :integer
    end
  end
end
