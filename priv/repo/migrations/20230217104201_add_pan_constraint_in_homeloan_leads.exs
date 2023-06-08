defmodule BnApis.Repo.Migrations.AddPanConstraintInHomeloanLeads do
  use Ecto.Migration

  def change do
    drop unique_index(:homeloan_leads, :pan,
           where: "active = true",
           name: :unique_pan_active_leads
         )

    create index(
             :homeloan_leads,
             [:pan, :loan_type, :phone_number],
             name: :unique_phone_number_pan_loan_type_active_leads,
             where: "active = true",
             unique: true
           )
  end
end
