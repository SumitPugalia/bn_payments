defmodule BnApis.Repo.Migrations.DropPhoneUniquenessOnHomeloanLeads do
  use Ecto.Migration

  def change do
    drop unique_index(:homeloan_leads, [:phone_number])
  end
end
