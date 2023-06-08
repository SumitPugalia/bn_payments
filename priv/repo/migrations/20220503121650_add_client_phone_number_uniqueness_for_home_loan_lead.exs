defmodule BnApis.Repo.Migrations.AddClientPhoneNumberUniquenessForHomeLoanLead do
  use Ecto.Migration

  def change do
    create unique_index(:homeloan_leads, [:phone_number])
  end
end
