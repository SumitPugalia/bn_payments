defmodule BnApis.Repo.Migrations.CreateCoapplicantHlTable do
  use Ecto.Migration

  def change do
    create table(:loan_coapplicants) do
      add(:name, :string)
      add(:employment_type, :integer)
      add(:resident, :string)
      add(:gender, :string)
      add(:cibil_score, :float)
      add(:date_of_birth, :integer)
      add(:income_details, :integer)
      add(:additional_income, :integer)
      add(:existing_loan_emi, :integer)
      add(:active, :boolean, default: true)
      add(:email_id, :string)

      add(:homeloan_lead_id, references(:homeloan_leads), null: false)
      timestamps()
    end
  end
end
