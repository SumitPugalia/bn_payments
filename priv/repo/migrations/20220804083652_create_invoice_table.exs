defmodule BnApis.Repo.Migrations.CreateInvoiceTable do
  use Ecto.Migration

  def change do
    create table(:invoices) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:status, :string, null: false)
      add(:invoice_number, :string, null: false)
      add(:invoice_date, :integer, null: false)
      add(:broker_id, references(:brokers))
      add(:story_id, references(:stories))
      add(:legal_entity_id, references(:legal_entities))
      add(:billing_company_id, references(:billing_companies))

      timestamps()
    end

    create index(:invoices, [:status])
    create index(:invoices, [:invoice_number])
    create index(:invoices, [:broker_id])
    create index(:invoices, [:story_id])
    create index(:invoices, [:legal_entity_id])
  end
end
