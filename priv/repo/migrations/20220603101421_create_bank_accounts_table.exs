defmodule BnApis.Repo.Migrations.CreateBankAccountsTable do
  use Ecto.Migration

  def change do
    create table(:bank_accounts) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:account_holder_name, :string, null: false)
      add(:ifsc, :string, null: false)
      add(:bank_account_type, :string, null: false)
      add(:account_number, :integer, null: false)
      add(:confirm_account_number, :integer, null: false)
      add(:bank_name, :string)
      add(:cancelled_cheque, :string)
      add(:active, :boolean, default: true)
      add(:billing_company_id, references(:billing_companies))

      timestamps()
    end

    create(
      unique_index(
        :bank_accounts,
        [:billing_company_id, :account_number, :active],
        where: "active = true",
        name: :unique_bank_account_billing_company_index
      )
    )
  end
end
