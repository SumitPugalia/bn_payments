defmodule BnApis.Repo.Migrations.AddFieldsHlLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:property_agreement_value, :integer)
      add(:property_all_inclusive_cost, :integer)
      add(:property_own_contribution, :integer)
      add(:property_type, :string)
      add(:email_id, :string)
      add(:resident, :string)
      add(:gender, :string)
      add(:cibil_score, :float)
      add(:date_of_birth, :integer)
      add(:income_details, :integer)
      add(:additional_income, :integer)
      add(:existing_loan_emi, :integer)
      add(:preferred_banks, {:array, :string}, default: [])
      add(:is_finalised_property, :boolean, default: false)
      add(:tentative_sanction_date, :integer)
      add(:is_roc_required, :boolean, default: false)
      add(:los_number, :integer)
      add(:any_case_lodged, :boolean, default: false)
      add(:commission_percent, :float)
      add(:loan_disbursed, :integer)
      add(:commission_disbursed, :integer)
    end
  end
end
