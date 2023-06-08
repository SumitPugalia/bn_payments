defmodule BnApis.Repo.Migrations.CreateInvoiceRemarks do
  use Ecto.Migration

  def change do
    create table(:invoice_remarks) do
      add :remark, :string
      add :employee_credential_id, references(:employees_credentials, on_delete: :nothing)
      add :invoice_id, references(:invoices, on_delete: :nothing)
      add(:active, :boolean, default: true)
      timestamps()
    end
  end
end
