defmodule BnApis.Repo.Migrations.CreateLoanDisbursementTable do
  use Ecto.Migration

  def change do
    create table(:loan_disbursements) do
      add(:disbursement_date, :integer)
      add(:loan_disbursed, :integer)
      add(:loan_commission, :float)

      add(:homeloan_lead_id, references(:homeloan_leads))

      timestamps()
    end
  end
end
