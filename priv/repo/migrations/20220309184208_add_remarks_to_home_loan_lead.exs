defmodule BnApis.Repo.Migrations.AddRemarksToHomeLoanLead do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:remarks, :string)
    end
  end
end
