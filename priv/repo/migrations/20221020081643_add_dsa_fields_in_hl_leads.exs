defmodule BnApis.Repo.Migrations.AddDsaFieldsInHlLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add(:lead_creation_date, :integer)
      add(:bank_name, :string)
      add(:branch_name, :string)
      add(:fully_disbursed, :boolean, default: false)
      add(:loan_type, :string)
      add(:property_stage, :string)
      add(:processing_type, :string)
      add(:application_id, :integer)
      add(:bank_rm, :string)
      add(:bank_rm_phone_number, :string)
      add(:sanctioned_amount, :integer)
      add(:rejected_lost_reason, :string)
      add(:rejected_doc_url, :string)
    end
  end
end
