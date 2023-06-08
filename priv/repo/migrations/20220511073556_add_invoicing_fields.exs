defmodule BnApis.Repo.Migrations.AddInvoicingFields do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:is_invoicing_enabled, :boolean, default: false)
      add(:invoicing_type, :string)
      add(:brokerage_proof_url, :string)
      add(:advanced_brokerage_percent, :integer)
    end

    create index(:stories, [:is_invoicing_enabled])
    create index(:stories, [:invoicing_type])
  end
end
