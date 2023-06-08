defmodule BnApis.Repo.Migrations.CreateLoanFilesTable do
  use Ecto.Migration

  def change do
    create table(:loan_files) do
      add(:status_id, :integer, null: false)
      add(:active, :boolean, default: true)
      add(:application_id, :string)
      add(:lan, :string)
      add(:bank_rm_name, :string)
      add(:bank_rm_phone_number, :string)
      add(:sanctioned_amount, :bigint)
      add(:sanctioned_doc_url, :string)
      add(:bank_id, references(:homeloan_banks), null: false)
      add(:homeloan_lead_id, references(:homeloan_leads), null: false)
      timestamps()
    end
  end
end
